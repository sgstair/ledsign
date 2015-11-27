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
            Width = Components.Max((c) => c.Width + c.X);
            Height = Components.Max((c) => c.Height + c.Y);
        }
    }
    public class SignComponent
    {
        public int X, Y, Width, Height;
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
            Font f = GetFont(pixelHeight);
            SignGraphics.DrawString(text, f, new SolidBrush(c), x, y);
        }

    }
}
