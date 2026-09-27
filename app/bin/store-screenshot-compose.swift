// Issue #161: ストア用スクショの合成。Simulator の生スクショに緑グラデ背景と
// 白抜き 2 行コピーを重ね、Apple 仕様寸法ちょうどの PNG を書き出す。
// 依存追加を避けるため CoreGraphics / CoreText / ImageIO だけを使う。
//
// usage: swift store-screenshot-compose.swift <input.png> <output.png> <width> <height> <lang> <line1> [line2]
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 7, let width = Int(args[3]), let height = Int(args[4]) else {
    FileHandle.standardError.write(
        "usage: store-screenshot-compose.swift <input> <output> <width> <height> <lang> <line1> [line2]\n".data(using: .utf8)!
    )
    exit(64)
}
let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
let language = args[5]
let lines = Array(args[6...]).filter { !$0.isEmpty }

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let shot = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("cannot read \(inputURL.path)\n".data(using: .utf8)!)
    exit(66)
}

let W = CGFloat(width), H = CGFloat(height)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(70) }

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

// 背景: 旧ストア画像 (docs/ver1_2/screen) から採取した上端 #B4D957 → 下端 #D7F4FD。
// CGContext の原点は左下なので、上端色を y = H に置く。
let gradient = CGGradient(colorsSpace: space, colors: [rgb(0xB4D957), rgb(0xD7F4FD)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// コピー: 白抜き、中央揃え。フォントサイズは幅基準 (旧デザイン実測で幅の約 7.5%)。
// フォント名を直指定すると SF はシステム UI フォント扱いで Times にフォールバックするため、
// 言語コードから emphasized system font を引く (ja は Hiragino、en は SF になる)。
// 最長行が幅の 88% を超える時は収まるまで縮小する (en は ja より文字列が長い)。
func makeLines(size: CGFloat) -> [CTLine] {
    let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, language as CFString)!
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): rgb(0xFFFFFF),
    ]
    return lines.map { CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: attributes)) }
}
var fontSize = W * 0.075
var ctLines = makeLines(size: fontSize)
let widest = ctLines.map { CTLineGetBoundsWithOptions($0, []).width }.max() ?? 0
if widest > W * 0.88 {
    fontSize *= W * 0.88 / widest
    ctLines = makeLines(size: fontSize)
}
let lineHeight = fontSize * 1.3
var baseline = H - H * 0.06 - fontSize
for line in ctLines {
    let bounds = CTLineGetBoundsWithOptions(line, [])
    ctx.textPosition = CGPoint(x: (W - bounds.width) / 2 - bounds.minX, y: baseline)
    CTLineDraw(line, ctx)
    baseline -= lineHeight
}

// 画面: 幅の 80% に縮小し、コピーの下に角丸 + 影で配置。下端ははみ出してよい (旧デザインと同じ)。
let shotWidth = W * 0.80
let shotHeight = shotWidth * CGFloat(shot.height) / CGFloat(shot.width)
let shotTop = H * 0.06 + lineHeight * CGFloat(max(lines.count, 1)) + H * 0.04
let shotRect = CGRect(x: (W - shotWidth) / 2, y: H - shotTop - shotHeight, width: shotWidth, height: shotHeight)
let radius = shotWidth * 0.09
let path = CGPath(roundedRect: shotRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.01), blur: W * 0.04, color: CGColor(gray: 0, alpha: 0.25))
ctx.addPath(path)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(path)
ctx.clip()
ctx.interpolationQuality = .high
ctx.draw(shot, in: shotRect)
ctx.restoreGState()

guard let output = ctx.makeImage(),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    exit(73)
}
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { exit(74) }
