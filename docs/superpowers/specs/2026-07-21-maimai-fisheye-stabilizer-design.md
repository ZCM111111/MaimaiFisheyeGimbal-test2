# Maimai Fisheye Stabilizer — Design Spec

## 1. Purpose

Build an iOS native app that turns an iPhone with a 238° fisheye lens into a real-time digital gimbal for filming maimai handcam videos. The app records a stabilized, rectilinear crop from the fisheye feed while the phone is chest/head-mounted, keeping the maimai screen and hands centered and level regardless of body motion.

## 2. Success Criteria

- Real-time preview latency low enough to not distract during gameplay (< 100 ms target).
- Record at **1080p60** and **4K60** with stable output frame rate.
- Output horizontal field of view ~90°–110°, capturing the full maimai screen plus both hands.
- Lock three axes (roll, pitch, yaw) using on-device motion sensors.
- Fisheye distortion correction is adjustable via a manual lens profile.
- No reliance on computer vision or AI in the first milestone.

## 3. Constraints

- iOS 17.0+, iPhone 13+ (Metal 3 GPU).
- Swift 5.9 / Xcode 15+.
- First milestone is sensor-only; AI-based maimai button/screen tracking is deferred.
- Lens profile starts as manually tunable; automatic calibration may be added later.

## 4. Architecture

The app is organized in four layers:

1. **Capture Layer**: `AVCaptureSession` + `AVCaptureVideoDataOutput` delivers raw BGRA frames at the selected resolution and frame rate.
2. **Motion Layer**: `CMMotionManager` streams `CMDeviceMotion` at 120 Hz, providing roll, pitch, yaw, and acceleration.
3. **Render Layer**: A custom Metal fragment shader performs single-pass fisheye correction, 3-axis counter-rotation, and cropping to the output frame.
4. **Recording Layer**: `AVAssetWriter` encodes the stabilized frames to a `.mov` file (H.264/HEVC) while `MTKView` drives the live preview.

## 5. Data Flow

```
Camera (60 fps BGRA) ──┐
                       ▼
Motion (120 Hz) ──▶ Metal Shader ──▶ MTKView (preview)
                       │
                       ▼
                  AVAssetWriter (record)
```

For every camera frame, the shader samples the current smoothed orientation from the motion layer. It maps each output pixel back into the fisheye source image using the inverse lens model and a 3D rotation matrix, then samples the color. The result is a straight, stabilized crop.

## 6. Key Components

| Component | Responsibility |
|-----------|----------------|
| `CameraManager` | Configures capture session, resolution/frame-rate selection, focus/exposure. |
| `MotionManager` | Wraps `CMMotionManager`, provides smoothed roll/pitch/yaw and a snapshot API. |
| `LensProfile` | Stores focal length, principal point, and distortion coefficients for the 238° lens; persisted per preset. |
| `MetalPipeline` | Sets up `MTLDevice`, command queue, textures, render pass descriptor. |
| `StabilizerShader` | Fragment shader: inverse fisheye mapping + 3D rotation + crop. |
| `Recorder` | Manages `AVAssetWriter`, pixel buffer pooling, audio sync (optional in v1). |
| `SettingsView` | SwiftUI panel for lens parameters, stabilization strength, output resolution, and re-center. |

## 7. Stabilization Algorithm

The shader receives:

- `roll`, `pitch`, `yaw` in radians (smoothed and unwrapped to avoid jumps).
- `lensProfile` constants.
- `outputFov` horizontal field of view.
- `strength` blend factor.

Per output pixel:

1. Generate a ray in the output rectilinear camera model.
2. Apply the inverse of the phone’s current rotation (roll/pitch/yaw) to the ray.
3. Map the rotated ray to a point in the fisheye image using the inverse fisheye projection.
4. Sample the source texture with bilinear filtering.
5. If the mapped point falls outside the source image, clamp to the edge color to avoid black borders.

The motion layer low-pass filters raw sensor angles and provides a "re-center" action that resets the reference orientation to the current phone pose.

## 8. User Interface

- Full-screen stabilized preview.
- Large red record button (start/stop).
- Settings button opening a bottom sheet with:
  - Resolution selector: 1080p60 / 4K60.
  - Lens profile sliders: focal length, center X/Y, distortion K1/K2.
  - Stabilization sliders: strength, smoothing, max offset.
  - Re-center button.
- Status overlay: resolution, frame rate, recording duration, thermal warning.

## 9. Error Handling & Edge Cases

- **Excessive motion**: Clamp crop offset to the available fisheye margin; never show black borders.
- **Thermal throttling**: Drop from 4K60 to 1080p60 automatically; pause recording if necessary.
- **Motion data gap**: Hold last valid orientation and interpolate; do not snap to zero.
- **Lens profile out of range**: Visualize the boundary in the preview so the user can tune parameters.
- **Storage full**: Stop recording gracefully and notify the user.

## 10. Testing Strategy

1. Validate the Metal shader on 1080p60 first.
2. Enable 4K60 and monitor frame time, CPU/GPU usage, and thermal state.
3. Wear the phone chest-mounted and record maimai gameplay; evaluate stability and latency.
4. Stress-test with rapid roll/pitch/yaw to confirm margin limits and edge clamping.
5. Compare output against unstabilized source to quantify drift and crop usage.

## 11. Out of Scope (First Milestone)

- AI detection of maimai buttons or inner screen.
- Automatic lens calibration.
- Audio recording and sync.
- Multi-lens support or lens switching.
- Social sharing or gallery editing.

## 12. Future Work

- Integrate a vision model to detect the maimai screen and auto-align the crop center.
- Add automatic checkerboard-based lens calibration.
- Add audio recording.
- Explore gyro+visual fusion to eliminate long-term drift without sacrificing low latency.
