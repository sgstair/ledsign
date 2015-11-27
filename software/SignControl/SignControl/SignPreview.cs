using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace SignControl
{
    public partial class SignPreview : Form, ISignTarget
    {
        static int PreviewIndex = 1;
        public SignPreview()
        {
            lockObj = new object();
            SignName = "Sign Preview";
            if (PreviewIndex > 1) 
                SignName += " " + PreviewIndex;
            PreviewIndex++;

            InitializeComponent();

            Text = SignName;

            SignComponent[] c  = new SignComponent[2];
            c[0] = new SignComponent() { X = 0, Y = 0, Width = 32, Height = 32 };
            c[1] = new SignComponent() { X = 32, Y = 0, Width = 32, Height = 32 };
            CurrentConfig = new SignConfiguration(c);
            ResizeForConfiguration();
        }

        object lockObj;

        Bitmap CurrentRender;
        SignConfiguration CurrentConfig;
        int ScaleBy = 4;

        public bool SupportsConfiguration(SignConfiguration configuration)
        {
            return true;
        }
        public void ApplyConfiguration(SignConfiguration configuration)
        {
            lock (lockObj)
            {
                CurrentConfig = configuration;
            }
            ResizeForConfiguration();
        }
        public void SendImage(Bitmap signImage)
        {
            lock(lockObj)
            {
                if(CurrentRender == null || CurrentRender.Width != signImage.Width || CurrentRender.Height != signImage.Height)
                {
                    CurrentRender = new Bitmap(signImage);
                }
                else
                {
                    Graphics g = Graphics.FromImage(CurrentRender);
                    g.DrawImageUnscaled(signImage, Point.Empty);
                }
                Invalidate();
            }
        }
        public SignConfiguration CurrentConfiguration()
        {
            return CurrentConfig;
        }

        public string SignName { get; private set; }

        void ResizeForConfiguration()
        {

        }

        private void SignPreview_Paint(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Color.DarkBlue);
            lock (lockObj)
            {
                if (CurrentRender == null)
                    return;

                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;

                foreach (SignComponent c in CurrentConfig.Components)
                {
                    Rectangle srcRect = new Rectangle(c.X, c.Y, c.Width, c.Height);
                    Rectangle destRect = new Rectangle(c.X * ScaleBy, c.Y * ScaleBy, c.Width * ScaleBy, c.Height * ScaleBy);
                    g.DrawImage(CurrentRender, destRect, srcRect, GraphicsUnit.Pixel);
                }
            }
        }

    }
}
