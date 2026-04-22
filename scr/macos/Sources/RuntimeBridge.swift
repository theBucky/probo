enum RuntimeBridge {
    static func rewrite(
        deltaAxis1: Int32,
        deltaAxis2: Int32,
        intensity: ScrollIntensity,
        isContinuous: Bool,
        hasPhase: Bool
    ) -> (linesX: Int32, linesY: Int32)? {
        let output = probo_process_wheel(probo_wheel_input_t(
            delta_axis1: deltaAxis1,
            delta_axis2: deltaAxis2,
            intensity: intensity.runtimeValue,
            is_continuous: isContinuous ? 1 : 0,
            has_phase: hasPhase ? 1 : 0
        ))

        guard output.rewrite != 0 else { return nil }
        return (output.out_lines_x, output.out_lines_y)
    }
}
