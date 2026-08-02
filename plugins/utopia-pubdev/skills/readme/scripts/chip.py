#!/usr/bin/env python3
"""Render a Utopia brand "chip" header as a self-contained HTML page.

The HTML is screenshotted to a transparent PNG by render.mjs. See brand-spec.md
for the locked recipe (Clay style, colour logo, Ubuntu wordmark, flush-left).

Usage:  python3 chip.py <package_name> <out.html>
"""
import sys

# colour standalone mark (Group.svg): black structure + blue flame, fold overlay.
MARK = '''<path fill="#000000" d="M155.162 908.342C155.162 908.342 -22.0708 653.434 224.368 393.463C485.998 117.454 808.393 301.46 808.393 301.46L890.258 260.101C796.578 195.108 686.018 160.501 571.238 160.501C262.346 160.501 10 412.876 10 721.804C10 857.698 58.95 986.84 145.879 1088.13C146.723 1088.97 112.12 1018.07 155.162 908.342Z"/>
<path fill="#000000" d="M569.551 519.228C-165.545 1130.33 431.984 1276.35 431.984 1276.35C785.606 1364.14 1135.85 1084.75 1135.85 725.18C1135.85 581.689 1081 449.171 990.69 351.259L931.613 402.748C1013.48 494.751 1063.27 655.123 1047.24 785.952C1008.41 1089.82 629.472 1229.09 475.026 1158.19C35.319 955.61 1053.14 232.247 1053.14 232.247C1053.14 232.247 729.905 386.71 569.551 519.228Z"/>
<path fill="#000000" d="M1097.03 327.626L1230.38 105.637L980.563 163.033L1098.72 201.016L1097.03 327.626Z"/>
<path fill="#7BCDF3" d="M238.843 0C270.914 33.7626 286.949 76.8099 286.949 119.857C286.105 162.904 269.226 205.952 236.311 238.026L169.638 303.019C135.879 335.094 118.999 378.141 118.999 421.188C118.155 464.236 134.191 507.282 166.262 541.045L48.9501 420.344C16.8794 386.581 0.843994 343.534 0.843994 300.487C1.68796 257.439 18.5673 214.392 51.4821 182.318L238.843 0Z"/>
<path fill="#0B5EA2" d="M168.793 303.863L233.779 370.544C235.467 372.233 236.311 373.077 237.999 374.765C254.878 393.334 266.694 414.435 274.289 437.225C279.353 454.106 282.729 472.676 281.885 490.401C281.041 533.448 264.162 576.496 231.247 608.57L166.262 541.889C134.191 508.127 118.155 465.079 118.999 422.032C118.155 378.985 135.035 335.938 168.793 303.863Z"/>
<path fill="#1F1E21" opacity="0.5" d="M168.794 303.863L185.673 321.588C151.914 353.663 135.035 396.71 135.035 439.757C134.191 482.805 150.226 525.852 182.297 559.614L165.418 541.889C133.347 508.127 117.311 465.079 118.155 422.032C118.155 378.985 135.035 335.938 168.794 303.863Z"/>'''

ACR = {"cms": "CMS", "cli": "CLI", "rest": "REST", "graphql": "GraphQL",
       "api": "API", "ui": "UI", "sql": "SQL", "http": "HTTP", "io": "IO"}


def main_word(pkg):
    s = pkg[len("utopia_"):] if pkg.startswith("utopia_") else pkg
    return " ".join(ACR.get(p, p.capitalize()) for p in s.split("_"))


def chip_html(pkg, pad="6px 30px 24px 0"):
    mw = main_word(pkg)
    ms = 27 if len(mw) < 8 else 24          # two modes (see brand-spec.md)
    ts = 13                                  # "Utopia" fixed
    mark = '<svg class="mark" style="height:50px" viewBox="0 0 1231 1293"><use href="#mark"/></svg>'
    chip = ('<div class="chip clay">%s<div class="wm">'
            '<span class="top" style="font-size:%dpx">Utopia</span>'
            '<span class="main" style="font-size:%dpx">%s</span></div></div>') % (mark, ts, ms, mw)
    return '''<!DOCTYPE html><html><head><meta charset="UTF-8"/>
<style>
@import url('https://fonts.googleapis.com/css2?family=Ubuntu:wght@400;500;700&display=swap');
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:transparent}
#cap{display:inline-block;padding:%s}
.mark{width:auto;aspect-ratio:1231/1293;display:block;flex:0 0 auto}
.wm{font-family:'Ubuntu',sans-serif;line-height:1;display:flex;flex-direction:column;color:#000}
.wm .top{font-weight:500;margin-bottom:2px;line-height:1}
.wm .main{font-weight:700;letter-spacing:-.01em;line-height:1;white-space:nowrap}
.chip{display:inline-flex;align-items:center;gap:18px;border-radius:999px}
.clay{background:#F6F7F9;border:2px solid rgba(255,255,255,.85);padding:16px 30px 16px 20px;
  box-shadow:inset -3px -3px 8px rgba(15,23,42,.05),inset 3px 3px 8px rgba(255,255,255,.9),9px 9px 22px -8px rgba(16,24,40,.30)}
</style></head><body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><symbol id="mark" viewBox="0 0 1231 1293">%s</symbol></svg>
<div id="cap">%s</div>
</body></html>''' % (pad, MARK, chip)


if __name__ == "__main__":
    open(sys.argv[2], "w").write(chip_html(sys.argv[1]))
    print("wrote", sys.argv[2], "for", sys.argv[1], "->", main_word(sys.argv[1]))
