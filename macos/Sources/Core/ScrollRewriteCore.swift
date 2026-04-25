struct ScrollRewriteInput: Sendable {
  var deltaAxis1: Int32
  var deltaAxis2: Int32
  var intensity: ScrollIntensity
  var isContinuous: Bool
  var hasPhase: Bool
  var isPrecision: Bool
}

struct ScrollRewriteOutput: Sendable {
  var linesX: Int32
  var linesY: Int32
}

enum ScrollRewriteCore {
  private static let precisionStepLines: Int32 = 1
  private static let slowStepLines: Int32 = 2
  private static let mediumStepLines: Int32 = 3

  static func rewrite(_ input: ScrollRewriteInput) -> ScrollRewriteOutput? {
    if input.isContinuous || input.hasPhase {
      return nil
    }
    if (input.deltaAxis1 != 0) == (input.deltaAxis2 != 0) {
      return nil
    }

    let stepLines = stepLines(for: input.intensity, isPrecision: input.isPrecision)
    return ScrollRewriteOutput(
      linesX: input.deltaAxis2.signum() * stepLines,
      linesY: input.deltaAxis1.signum() * stepLines
    )
  }

  private static func stepLines(for intensity: ScrollIntensity, isPrecision: Bool) -> Int32 {
    if isPrecision {
      return precisionStepLines
    }
    switch intensity {
    case .slow:
      return slowStepLines
    case .medium:
      return mediumStepLines
    }
  }

}
