/*
 *   Copyright (c) 2008-2018 SLIBIO <https://github.com/SLIBIO>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *   THE SOFTWARE.
 */

#include "slib/core/definition.h"

#if defined(SLIB_GRAPHICS_IS_QUARTZ)

#include "slib/graphics/canvas.h"

#include "slib/graphics/platform.h"

#include <CoreText/CoreText.h>
#include <CoreImage/CoreImage.h>

namespace slib
{

	class _priv_Quartz_Canvas : public CanvasExt
	{
		SLIB_DECLARE_OBJECT
		
	public:
		CGContextRef m_graphics;
		
	public:
		_priv_Quartz_Canvas()
		{
		}
		
		~_priv_Quartz_Canvas()
		{
			CGContextRelease(m_graphics);
		}
		
	public:
		static Ref<_priv_Quartz_Canvas> _create(CanvasType type, CGContextRef graphics, sl_real width, sl_real height)
		{
			if (graphics) {
				
				Ref<_priv_Quartz_Canvas> ret = new _priv_Quartz_Canvas();
				
				if (ret.isNotNull()) {
					
					ret->m_graphics = graphics;
					CGContextRetain(graphics);
					
					ret->setType(type);
					ret->setSize(Size(width, height));
					
					ret->_setAntiAlias(sl_true);
					
					return ret;
				}
			}
			return sl_null;
		}
		
		void save() override
		{
			CGContextSaveGState(m_graphics);
		}
		
		void restore() override
		{
			CGContextRestoreGState(m_graphics);
		}
		
		Rectangle getClipBounds() override
		{
			CGRect rc = CGContextGetClipBoundingBox(m_graphics);
			return Rectangle((sl_real)(rc.origin.x), (sl_real)(rc.origin.y), (sl_real)(rc.origin.x + rc.size.width), (sl_real)(rc.origin.y + rc.size.height));
		}

		void clipToRectangle(const Rectangle& rect) override
		{
			CGRect rc;
			rc.origin.x = rect.left;
			rc.origin.y = rect.top;
			rc.size.width = rect.getWidth();
			rc.size.height = rect.getHeight();
			CGContextClipToRect(m_graphics, rc);
		}
		
		void clipToPath(const Ref<GraphicsPath>& path) override
		{
			if (path.isNotNull()) {
				CGPathRef handle = GraphicsPlatform::getGraphicsPath(path.get());
				if (handle) {
					_clipToPath(handle, path->getFillMode());				
				}
			}
		}
		
		void _clipToPath(CGPathRef path, FillMode fillMode)
		{
			CGContextBeginPath(m_graphics);
			CGContextAddPath(m_graphics, path);
			if (fillMode != FillMode::Winding) {
				CGContextEOClip(m_graphics);
			} else {
				CGContextClip(m_graphics);
			}
		}
		
		Matrix3 getMatrix()
		{
			Matrix3 ret;
			CGAffineTransform t = CGContextGetCTM(m_graphics);
			GraphicsPlatform::getMatrix3FromCGAffineTransform(ret, t);
			return ret;
		}
		
		void concatMatrix(const Matrix3& other) override
		{
			CGAffineTransform t;
			GraphicsPlatform::getCGAffineTransform(t, other);
			CGContextConcatCTM(m_graphics, t);
		}
		
		void drawText(const String& text, sl_real x, sl_real y, const Ref<Font>& in_font, const Color& _color) override
		{		
			if (text.isNotEmpty()) {
				
				Ref<Font> _font = in_font;
				if (_font.isNull()) {
					_font = Font::getDefault();
				}
				if (_font.isNotNull()) {
					
					CTFontRef font = GraphicsPlatform::getCoreTextFont(_font.get());
					
					if (font) {
						
						NSString* ns_text = Apple::getNSStringFromString(text);
						CFStringRef string = (__bridge CFStringRef)ns_text;
						
						SInt32 _underline = _font->isUnderline() ? kCTUnderlineStyleSingle: kCTUnderlineStyleNone;
						CFNumberRef underline = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &_underline);
						
						CGFloat colorComponents[4] = {_color.getRedF(), _color.getGreenF(), _color.getBlueF(), _color.getAlphaF()};
						CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
						CGColorRef color = CGColorCreate(colorSpace, colorComponents);
						CFRelease(colorSpace);
						CFStringRef keys[] = { kCTFontAttributeName, kCTUnderlineStyleAttributeName, kCTForegroundColorAttributeName };
						CFTypeRef values[] = { font, underline, color };
						CFDictionaryRef attributes = CFDictionaryCreate(
																		kCFAllocatorDefault,
																		(const void**)&keys, (const void**)&values,
																		sizeof(keys) / sizeof(keys[0]),
																		&kCFCopyStringDictionaryKeyCallBacks,
																		&kCFTypeDictionaryValueCallBacks);
						if (attributes) {
							CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, string, attributes);
							if (attrString) {
								CTLineRef line = CTLineCreateWithAttributedString(attrString);
								if (line) {
									CGFloat ascent, descent, leading;
									CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
									CGAffineTransform trans;
									trans.a = 1;
									trans.b = 0;
									trans.c = 0;
									trans.d = -1;
									trans.tx = x;
									trans.ty = y + ascent + leading;
									
									CGContextSaveGState(m_graphics);
									CGContextSetTextMatrix(m_graphics, trans);
									
									CTLineDraw(line, m_graphics);
									
									if (_font->isStrikeout()) {
										CGFloat yStrike = descent + ascent / 2;
										CGFloat widthStrike = _font->measureText(text).x;
										CGContextBeginPath(m_graphics);
										CGContextMoveToPoint(m_graphics, 0, yStrike);
										CGContextAddLineToPoint(m_graphics, widthStrike, yStrike);
										CGContextSetRGBStrokeColor(m_graphics, _color.getRedF(), _color.getGreenF(), _color.getBlueF(), _color.getAlphaF());
										CGContextStrokePath(m_graphics);
									}
									
									CGContextRestoreGState(m_graphics);
									CFRelease(line);
								}
								CFRelease(attrString);
							}
							CFRelease(attributes);
						}
						
						CFRelease(underline);
						CFRelease(color);
					}
					
				}
			}
		}
		
		void drawLine(const Point& pt1, const Point& pt2, const Ref<Pen>& _pen) override
		{
			Ref<Pen> pen = _pen;
			if (pen.isNull()) {
				pen = Pen::getDefault();
			}
			if (pen.isNotNull()) {
				CGContextBeginPath(m_graphics);
				CGContextMoveToPoint(m_graphics, pt1.x, pt1.y);
				CGContextAddLineToPoint(m_graphics, pt2.x, pt2.y);
				_applyPen(pen.get());
				CGContextStrokePath(m_graphics);
			}
		}
		
		void drawLines(const Point* points, sl_uint32 countPoints, const Ref<Pen>& _pen) override
		{
			if (countPoints < 2) {
				return;
			}
			Ref<Pen> pen = _pen;
			if (pen.isNull()) {
				pen = Pen::getDefault();
			}
			if (pen.isNotNull()) {
				CGContextBeginPath(m_graphics);
				CGContextMoveToPoint(m_graphics, points[0].x, points[0].y);
				for (sl_uint32 i = 1; i < countPoints; i++) {
					CGContextAddLineToPoint(m_graphics, points[i].x, points[i].y);
				}
				_applyPen(pen.get());
				CGContextStrokePath(m_graphics);
			}
		}
		
		void drawArc(const Rectangle& rect, sl_real startDegrees, sl_real sweepDegrees, const Ref<Pen>& pen) override
		{
			Ref<GraphicsPath> path = GraphicsPath::create();
			if (path.isNotNull()) {
				path->addArc(rect, startDegrees, sweepDegrees);
				drawPath(path, pen, Ref<Brush>::null());
			}
		}
		
		void drawRectangle(const Rectangle& _rect, const Ref<Pen>& _pen, const Ref<Brush>& brush) override
		{
			CGRect rect;
			rect.origin.x = _rect.left;
			rect.origin.y = _rect.top;
			rect.size.width = _rect.getWidth();
			rect.size.height = _rect.getHeight();
			if (brush.isNotNull()) {
				_applyBrush(brush.get());
				CGContextFillRect(m_graphics, rect);
			}
			Ref<Pen> pen = _pen;
			if (brush.isNull() && pen.isNull()) {
				pen = Pen::getDefault();
			}
			if (pen.isNotNull()) {
				_applyPen(pen.get());
				rect.origin.y++;
				CGContextStrokeRect(m_graphics, rect);
			}
		}
		
		void drawRoundRect(const Rectangle& rect, const Size& radius, const Ref<Pen>& pen, const Ref<Brush>& brush) override
		{
			Ref<GraphicsPath> path = GraphicsPath::create();
			if (path.isNotNull()) {
				path->addRoundRect(rect, radius);
				drawPath(path, pen, brush);
			}
		}
		
		void drawEllipse(const Rectangle& _rect, const Ref<Pen>& _pen, const Ref<Brush>& brush) override
		{
			CGRect rect;
			rect.origin.x = _rect.left;
			rect.origin.y = _rect.top;
			rect.size.width = _rect.getWidth();
			rect.size.height = _rect.getHeight();
			if (brush.isNotNull()) {
				_applyBrush(brush.get());
				CGContextFillEllipseInRect(m_graphics, rect);
			}
			Ref<Pen> pen = _pen;
			if (brush.isNull() && pen.isNull()) {
				pen = Pen::getDefault();
			}
			if (pen.isNotNull()) {
				_applyPen(pen.get());
				CGContextStrokeEllipseInRect(m_graphics, rect);
			}
		}
		
		void drawPolygon(const Point* points, sl_uint32 countPoints, const Ref<Pen>& pen, const Ref<Brush>& brush, FillMode fillMode) override
		{
			if (countPoints <= 2) {
				return;
			}
			Ref<GraphicsPath> path = GraphicsPath::create();
			if (path.isNotNull()) {
				path->moveTo(points[0]);
				for (sl_uint32 i = 1; i < countPoints; i++) {
					path->lineTo(points[i]);
				}
				path->closeSubpath();
				path->setFillMode(fillMode);
				drawPath(path, pen, brush);
			}
		}
		
		void drawPie(const Rectangle& rect, sl_real startDegrees, sl_real sweepDegrees, const Ref<Pen>& pen, const Ref<Brush>& brush) override
		{
			Ref<GraphicsPath> path = GraphicsPath::create();
			if (path.isNotNull()) {
				path->addPie(rect, startDegrees, sweepDegrees);
				drawPath(path, pen, brush);
			}
		}
		
		void drawPath(const Ref<GraphicsPath>& path, const Ref<Pen>& pen, const Ref<Brush>& brush) override
		{
			if (path.isNotNull()) {
				CGPathRef handle = GraphicsPlatform::getGraphicsPath(path.get());
				if (handle) {
					_drawPath(handle, pen, brush, path->getFillMode());
				}
			}
		}
		
		void _drawPath(CGPathRef path, const Ref<Pen>& _pen, const Ref<Brush>& brush, FillMode fillMode)
		{
			if (brush.isNotNull()) {
				_applyBrush(brush.get());
				CGContextBeginPath(m_graphics);
				CGContextAddPath(m_graphics, path);
				switch (fillMode) {
					case FillMode::Winding:
						CGContextFillPath(m_graphics);
						break;
					case FillMode::Alternate:
					default:
						CGContextEOFillPath(m_graphics);
						break;
				}
			}
			Ref<Pen> pen = _pen;
			if (brush.isNull() && pen.isNull()) {
				pen = Pen::getDefault();
			}
			if (pen.isNotNull()) {
				_applyPen(pen.get());
				CGContextBeginPath(m_graphics);
				CGContextAddPath(m_graphics, path);
				CGContextStrokePath(m_graphics);
			}
		}
		
		void _applyPen(Pen* pen)
		{
			CGContextRef graphics = m_graphics;
			
			CGFloat _width;
			CGLineCap _cap;
			CGLineJoin _join;
			CGFloat _miterLimit;
			CGFloat _dash[6];
			sl_uint32 _dashLen;
			
			_width = pen->getWidth();
			
			switch (pen->getCap()) {
				case LineCap::Square:
					_cap = kCGLineCapSquare;
					break;
				case LineCap::Round:
					_cap = kCGLineCapRound;
					break;
				case LineCap::Flat:
				default:
					_cap = kCGLineCapButt;
					break;
			}
			
			switch (pen->getJoin()) {
					break;
				case LineJoin::Bevel:
					_join = kCGLineJoinBevel;
					break;
				case LineJoin::Round:
					_join = kCGLineJoinRound;
					break;
				case LineJoin::Miter:
				default:
					_join = kCGLineJoinMiter;
					break;
			}
			
			_miterLimit = pen->getMiterLimit();
			
			switch (pen->getStyle()) {
				case PenStyle::Dot:
					_dash[0] = _width;
					_dash[1] = 2 * _width;
					_dashLen = 2;
					break;
				case PenStyle::Dash:
					_dash[0] = 3 * _width;
					_dash[1] = _dash[0];
					_dashLen = 2;
					break;
				case PenStyle::DashDot:
					_dash[0] = 3 * _width;
					_dash[1] = 2 * _width;
					_dash[2] = _width;
					_dash[3] = _dash[1];
					_dashLen = 4;
					break;
				case PenStyle::DashDotDot:
					_dash[0] = 3 * _width;
					_dash[1] = 2 * _width;
					_dash[2] = _width;
					_dash[3] = _dash[1];
					_dash[4] = _width;
					_dash[5] = _dash[1];
					_dashLen = 6;
					break;
				case PenStyle::Solid:
				default:
					_dashLen = 0;
					break;
			}
			
			CGContextSetLineWidth(graphics, _width);
			CGContextSetLineCap(graphics, _cap);
			CGContextSetLineJoin(graphics, _join);
			CGContextSetMiterLimit(graphics, _miterLimit);
			CGContextSetLineDash(graphics, 0, _dash, _dashLen);
			
			Color _color = pen->getColor();
			CGContextSetRGBStrokeColor(graphics, _color.getRedF(), _color.getGreenF(), _color.getBlueF(), _color.getAlphaF());
		}

		void _applyBrush(Brush* brush)
		{
			CGContextRef graphics = m_graphics;
			Color _color = brush->getColor();
			CGContextSetRGBFillColor(graphics, _color.getRedF(), _color.getGreenF(), _color.getBlueF(), _color.getAlphaF());
		}
		
		void _setAlpha(sl_real alpha) override
		{
			CGContextSetAlpha(m_graphics, (CGFloat)alpha);
		}
		
		void _setAntiAlias(sl_bool flag) override
		{
			if (flag) {
				CGContextSetAllowsAntialiasing(m_graphics, YES);
				CGContextSetShouldAntialias(m_graphics, YES);
				CGContextSetInterpolationQuality(m_graphics, kCGInterpolationMedium);
			} else {
				CGContextSetAllowsAntialiasing(m_graphics, NO);
				CGContextSetShouldAntialias(m_graphics, NO);
				CGContextSetInterpolationQuality(m_graphics, kCGInterpolationNone);
			}
		}
		
	};

	SLIB_DEFINE_OBJECT(_priv_Quartz_Canvas, Canvas)

	Ref<Canvas> GraphicsPlatform::createCanvas(CanvasType type, CGContextRef graphics, sl_uint32 width, sl_uint32 height)
	{
		if (!graphics) {
			return sl_null;
		}
		return _priv_Quartz_Canvas::_create(type, graphics, (sl_real)width, (sl_real)height);
	}

	CGContextRef GraphicsPlatform::getCanvasHandle(Canvas* _canvas)
	{
		if (_priv_Quartz_Canvas* canvas = CastInstance<_priv_Quartz_Canvas>(_canvas)) {
			return canvas->m_graphics;
		}
		return NULL;
	}

	SLIB_INLINE static CIVector* _getCIVector(const Vector4& v)
	{
		return [CIVector vectorWithX:(v.x) Y:(v.y) Z:(v.z) W:(v.w)];
	}

	void GraphicsPlatform::drawCGImage(Canvas* canvas, const Rectangle& _rectDst, CGImageRef image, sl_bool flagFlipY, const DrawParam& param)
	{
		if (!image) {
			return;
		}
		
		CGContextRef graphics = GraphicsPlatform::getCanvasHandle(canvas);
		if (!graphics) {
			return;
		}
		
		sl_bool flagBlur = param.isBlur();
		sl_bool flagOpaque = param.isOpaque();
		sl_bool flagTiled = param.tiled;
		
		CIImage* ciImage = nil;
		sl_bool flagFreeImage = sl_false;
		
		if (param.useColorMatrix || param.useBlur) {
			ciImage = [CIImage imageWithCGImage:image];
			if (ciImage != nil) {
				if (param.useColorMatrix) {
					CIFilter* filter = [CIFilter filterWithName:@"CIColorMatrix"];
					[filter setValue:ciImage forKey:kCIInputImageKey];
					[filter setValue:_getCIVector(param.colorMatrix.red) forKey:@"inputRVector"];
					[filter setValue:_getCIVector(param.colorMatrix.green) forKey:@"inputGVector"];
					[filter setValue:_getCIVector(param.colorMatrix.blue) forKey:@"inputBVector"];
					[filter setValue:_getCIVector(param.colorMatrix.alpha) forKey:@"inputAVector"];
					[filter setValue:_getCIVector(param.colorMatrix.bias) forKey:@"inputBiasVector"];
					ciImage = [filter outputImage];
				}
				if (flagBlur) {
					CIFilter* filter = [CIFilter filterWithName:@"CIBoxBlur"];
					[filter setValue:ciImage forKey:kCIInputImageKey];
					[filter setValue:[NSNumber numberWithFloat:param.blurRadius] forKey:@"inputRadius"];
					ciImage = [filter outputImage];
				}
				if (ciImage != nil) {
					if (flagTiled) {
						CIContext *ciContext = [CIContext contextWithOptions:nil];
						CGImageRef t = [ciContext createCGImage:ciImage fromRect:[ciImage extent]];
						if (t) {
							image = t;
							flagFreeImage = sl_true;
							ciImage = nil;
						}
					}
				}
			}
		}
		
		if (ciImage != nil) {
#if defined(SLIB_PLATFORM_IS_MACOS)
			NSGraphicsContext* oldContext = [NSGraphicsContext currentContext];
			NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:graphics flipped:NO];
			[NSGraphicsContext setCurrentContext:context];
#else
			UIGraphicsPushContext(graphics);
#endif
			
#if defined(SLIB_PLATFORM_IS_MACOS)
			NSRect rectDst;
#else
			CGRect rectDst;
#endif
			
			rectDst.origin.x = _rectDst.left;
			rectDst.origin.y = _rectDst.top;
			rectDst.size.width = _rectDst.getWidth();
			rectDst.size.height = _rectDst.getHeight();
					
#if defined(SLIB_PLATFORM_IS_MACOS)
			if (!flagFlipY) {
				CGContextSaveGState(graphics);
				CGContextTranslateCTM(graphics, 0, rectDst.origin.y + rectDst.size.height);
				CGContextScaleCTM(graphics, 1, -1);
				CGContextTranslateCTM(graphics, 0, -rectDst.origin.y);
			}
			
			NSRect rectSrc;
			rectSrc.origin.x = 0;
			rectSrc.origin.y = 0;
			rectSrc.size.width = CGImageGetWidth(image);
			rectSrc.size.height = CGImageGetHeight(image);
			[ciImage drawInRect:rectDst fromRect:rectSrc operation:NSCompositeSourceOver fraction:((flagOpaque?1:param.alpha) * canvas->getAlpha())];

			if (!flagFlipY) {
				CGContextRestoreGState(graphics);
			}
			
#else
			if (flagFlipY) {
				CGContextSaveGState(graphics);
				CGContextTranslateCTM(graphics, 0, rectDst.origin.y + rectDst.size.height);
				CGContextScaleCTM(graphics, 1, -1);
				CGContextTranslateCTM(graphics, 0, -rectDst.origin.y);
			} else {
				flagFlipY = flagFlipY;
			}

			[[UIImage imageWithCIImage:ciImage] drawInRect:rectDst blendMode:kCGBlendModeNormal alpha:((flagOpaque?1:param.alpha) * canvas->getAlpha())];

			if (flagFlipY) {
				CGContextRestoreGState(graphics);
			}
#endif
			

#if defined(SLIB_PLATFORM_IS_MACOS)
			[NSGraphicsContext setCurrentContext:oldContext];
#else
			UIGraphicsPopContext();
#endif
		} else {
			sl_bool flagSaveState = (!flagOpaque) || (!flagFlipY);
			if (flagSaveState) {
				CGContextSaveGState(graphics);
			}
			if (!flagOpaque) {
				CGContextSetAlpha(graphics, canvas->getAlpha() * param.alpha);
			}
			
			CGRect rectDst;
			rectDst.origin.x = _rectDst.left;
			rectDst.origin.y = _rectDst.top;
			rectDst.size.width = _rectDst.getWidth();
			rectDst.size.height = _rectDst.getHeight();
			if (!flagFlipY) {
				CGContextTranslateCTM(graphics, 0, rectDst.origin.y + rectDst.size.height);
				CGContextScaleCTM(graphics, 1, -1);
				CGContextTranslateCTM(graphics, 0, -rectDst.origin.y);
			}
			if (flagTiled) {
				CGContextDrawTiledImage(graphics, rectDst, image);
			} else {
				CGContextDrawImage(graphics, rectDst, image);
			}
			if (flagSaveState) {
				CGContextRestoreGState(graphics);
			}
		}
		if (flagFreeImage) {
			CGImageRelease(image);
		}
	}

}

#endif
