import Foundation

enum RuntimeBridge {
    static func setIntensity(_ intensity: ScrollIntensity) {
        probo_set_intensity(intensity.runtimeValue)
    }

    static func rewrite(deltaAxis1: Int32, deltaAxis2: Int32, isContinuous: Bool, hasPhase: Bool) -> (dx: Int32, dy: Int32)? {
        let output = probo_process_wheel(probo_wheel_input_t(
            delta_axis1: deltaAxis1,
            delta_axis2: deltaAxis2,
            is_continuous: isContinuous ? 1 : 0,
            has_phase: hasPhase ? 1 : 0
        ))

        guard output.rewrite != 0 else {
            return nil
        }

        return (output.out_dx, output.out_dy)
    }
}
