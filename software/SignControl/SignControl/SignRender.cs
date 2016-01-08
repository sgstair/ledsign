using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SignControl
{
    public interface ISignTarget
    {
        bool SupportsConfiguration(SignConfiguration configuration);
        void ApplyConfiguration(SignConfiguration configuration);
        void SendImage(Bitmap signImage);
        SignConfiguration CurrentConfiguration();
        string SignName { get; }
    }
    public class SignConfiguration
    {
        public readonly SignComponent[] Components;
        public int Width, Height;
        public SignConfiguration(SignComponent[] componentList)
        {
            Components = componentList;
            Width = Height = 32;
            if (Components.Length == 0) return;
            Width = Components.Max((c) => c.Width + c.X);
            Height = Components.Max((c) => c.Height + c.Y);
        }
    }
    public struct SignComponent
    {
        public int X, Y, Width, Height;

        public bool Overlaps(SignComponent other)
        {
            return (X + Width > other.X) &&
                (other.X + other.Width > X) &&
                (Y + Height > other.Y) &&
                (other.Y + other.Height > Y);

        }
    }

    public class SignRender
    {
        public Bitmap SignOutput;
        Graphics SignGraphics;
        public SignConfiguration Configuration { get; private set; }

        public int ElementXOffset, ElementYOffset;
        public float ElementOnScreenPercentage;

        public SignRender()
        {
            PixelFonts = new Dictionary<int, Font>();
        }


        public void Clear()
        {
            if(SignOutput != null)
            {
                SignGraphics.Clear(Color.Black);
            }
        }

        public void SetConfiguration(SignConfiguration c)
        {
            Configuration = c;
            if (c.Width > 0 && c.Height > 0)
            {
                SignOutput = new Bitmap(Configuration.Width, Configuration.Height);
                SignGraphics = Graphics.FromImage(SignOutput);
                SignGraphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                SignGraphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
                // (Disables cleartype, which doesn't make much sense on the LED sign)
            }
            else
            {
                SignOutput = null;
            }
        }

        Dictionary<int, Font> PixelFonts;

        Font GetFont(int pixelHeight)
        {
            if(!PixelFonts.ContainsKey(pixelHeight))
            {
                Font f = new Font(FontFamily.GenericSansSerif, pixelHeight, GraphicsUnit.Pixel);
                PixelFonts.Add(pixelHeight, f);
            }
            return PixelFonts[pixelHeight];
        }

        public SizeF MeasureText(int pixelHeight, string text)
        {
            Font f = GetFont(pixelHeight);
            return SignGraphics.MeasureString(text, f);
        }

        public void DrawText(int pixelHeight, string text, Color c, int xOffset = 0, int yOffset = 0)
        {
            float x = ElementXOffset + xOffset;
            float y = ElementYOffset + yOffset;
            DrawTextAbsolute(pixelHeight, text, c, x, y);
        }

        public void DrawTextAbsolute(int pixelHeight, string text, Color c, float x = 0, float y = 0)
        {
            Font f = GetFont(pixelHeight);
            SignGraphics.DrawString(text, f, new SolidBrush(c), x, y);
        }


        public void PrepareBitmapBackground(ref Bitmap bgBmp)
        {
            if(bgBmp != null)
            {
                if(bgBmp.Width != SignOutput.Width || bgBmp.Height != SignOutput.Height)
                {
                    bgBmp = null;
                }
            }
            if(bgBmp == null)
            {
                bgBmp = new Bitmap(SignOutput.Width, SignOutput.Height);
            }
        }

        public void DrawBackground(Bitmap bgBmp)
        {
            SignGraphics.DrawImageUnscaled(bgBmp, 0, 0);
        }
    }
}
