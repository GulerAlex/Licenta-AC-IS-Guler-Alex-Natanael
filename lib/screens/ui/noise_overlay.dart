import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

// Small 64x64 transparent noise texture encoded in base64
const String _noiseBase64 = 
  "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAQAAAAAYLlVAAADgElEQVR42tWaA3DUUBBEeR2sIBjBq4XjJ4oRBBE0+gQRjGAEwQjOIIhgBCMI/ogIRjACYQTv1QjCq0HwIIgQRBCEIJxX123L5t2+W+/d7d27e1/eNpt3b2/vv51s5//nf538//z+A/8/4/71/P8g7l8f/z/9/0n+f+n+E/P/g/y/nvuPRH81919E8Y+I4r/U4r9cxf/LtfwvFff/1sX/T6rE/a/6+N+M/qri3zQx/oX18e+j1z8g7j8p/WfN/Vcnxl/21/JfwL8H6rD8T4t/fH1/QfyfLP+z4+7Lwv9f7l85/7X+p14+Ie5fMf+/1/kX/v9H+K9L+T8s/+1z/b+y+S/i/6z5j+L/1/Sfk/e/m4Nfc//U+G9M+e+4/t8mIeH/P81/H/2XoX9fEuf/J/R/IOL/3/T/P8v/p/X8c/jvyz3/tvyvefjvi/P/Y5F/T/wfQf7//Pnv4r/n/j8B/Rdy/3vy/E/z/7X+r4v7n5Hnf2n8n5P8X4T+KzL+b6vH/5Xp3xf/l1H8q5n/3/f3v0tY/5zR/5/Fv5r/Vv9r4N+a+89P8W/k//e4fy2MfyPPvzb+G0z1byyX/71m/n/Z3H9qXv/cJfX/vfj/u5b/1uW/Jv5TzP/rG2P+6Qv+78r8l+L/Auvfx/1PltBfzv8n8Z+E+Z9y/ofFfHw/Z/8rxf+fxfyTxf/v6vwj1L+T+5+i4n8g5j8P/0GOf//G+d8J/dfN+Z/Qf2Gqfy08/gvx/y1z/hX1f6v/x2K+mvm/7f4T8q9B/9V4/Hvy/P9+jP9P+f8c1L8B+28T6n9YHP/vEvMfy/nPzvVvzfi/Uo9/eex/oYh/y/VvhH8N/Hsy/X8u17+J/jNx/XvH8Z9q5J+LpW8n1b/B1P+9YvxrI+Nfyfnn8P/9XP/a+a8j4x96E+K/zVz/tuz/O6Z/C6b/L+fzh+jfcP/BHP+A/g1e/zTlf3eGfy18/hO6f6H/d5L828T3v5Lnf4Pnf4D+/eL3H+L4tx2H/xDjX5TnH/r1h8j418fnX22mfg4U8d/q45+b/t/i+Dfk4d9D/i2s/j0U9t83Pv+W8h/1z8fjfz/P/4bVv3f8PoV1Px/nfwO5/Pcd7t/G6l+Dzz8b539Dnv9J/R+E/r07nv+FqX8h1z/v4T84rX/tE/Mv4//neP0bcv1bmPrfl/2viH+h/43o/zeT4n9g6r/5yP8C/Hsq7r9D7l8j1b/x8V/A/21M/Y+w7R3v/0tJ/Xsy/dvo1a/w46+PfyLXX1v/A7r/wvgnsfMfjPvfL8M/sPs/zPXPzeTfYKr/Qv8n9v+U45+Q/z9F9y+Q7z+Q3z+w3QfF+R+Y+reN2b8E/7+b8d+56+cf2PwHRvkvcP+V/Hch4//3Of695vrnFvpPzvdPYPs/MO4fkN+/bXj/2+D33zbDv51E/gMj/r1n/gPcfwF+/n2m+7f1/m2F/jey92/B82/n+1tw/Bvw+N/G6t+d2/gX6v82xv6FfP4Dff8W7P3bhH8t/Fuk+t+b8S/A848r//72/38v92/h//t2P98/d+L+A3H/gfT+bdv4n6TrHwr+Y2dJ/Dvw/a3z/C2y+Q+0+y/C+5+73n+R5z/A4x9o7F/Y/gMT/4Hs/oGZ/q19/yHxv8H7v50S/qHefwHev2U7/r05/gMR/oXcv0Xk3zJz/+yE+xey9B9I+LeMzD+r/4GEfwGhfws2/iW5/gM9/gXG/u2d/oM9f8sO/M+u8G/n9S/B8h/I519A9x+449+2mP9A0f8Crv8A3T/wf5pPq/8v0f0H4vkH4vyzuv8Cnn9g7H8Lbn8hZ/8CDv/BPv+BnP8A/7+kxy/I+rfl928T/3/y8N/W6T/wn//Iff62zP0HpvEPrPAvO+7fwv1vweI/uMs/0Ld/YZP/IMe/bbX+gxz/wQh/S7r/Evy/bT7+W7T7n8vbf/TjH7jn38b0H1jIP9DuP9DhH8jzD/Tpn872b+v8B1b6Fyz7B8j0L6DwD9TyL7i//2B9/kD//rWlf+DOv+V4/wN5/AMj/a1l+Qca/Aca/G2O/W3t6t/Wsf8Cnf4DW/2tS/2H3r+l1b+A5W8p+7cl2T9wf/4tbPlbl/gPlvIPnPjflubfVrd/q2f/2z//to72b+34t3XWv19y/Yda6N+B7L/g2O9vOfXvVwv9B7b6W+fy33K3v3XxX8Dnb1vN/rZ1xX8hj3/rWP6Bkf5WM/vbgulfSPHvtN2/M4H+rQv818A/sM1/wIE/sNN/4C5/6wL/rff/21abf+uF3B+y/a1n4t+o+/eC+t9W078Gnr9tHfqvoTf/ARf+VlP/ARf2Z3eQ2S1j1c8CRAAAAABJRU5ErkJggg==";

class NoiseOverlay extends StatelessWidget {
  const NoiseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.08,
        child: Image.memory(
          base64Decode(_noiseBase64),
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
          fit: BoxFit.none,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}