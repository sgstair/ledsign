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
    public partial class SignTargetConfigure : Form
    {
        public SignControl ParentWindow;

        public SignTargetConfigure(SignControl c)
        {
            ParentWindow = c;
            InitializeComponent();
        }

        Bitmap CurrentRender;
        public const int ScaleFactor = 2;
        public const int MaxX = 320;
        public const int MaxY = 240;

        public void UpdateFrame(Bitmap signImage)
        {
            if (!checkBox1.Checked)
                UpdateFrameInternal(signImage);
        }
        void UpdateFrameInternal(Bitmap signImage)
        {
            lock (this)
            {
                if (CurrentRender == null || CurrentRender.Width != signImage.Width || CurrentRender.Height != signImage.Height)
                {
                    CurrentRender = new Bitmap(signImage);
                }
                else
                {
                    Graphics g = Graphics.FromImage(CurrentRender);
                    g.DrawImageUnscaled(signImage, Point.Empty);
                }
                UpdateImages();
            }
        }

        internal List<EditElement> Elements;

        public SignTargetUI ResponseObject;
        ISignTarget Configuring;
        SignConfiguration InitialConfiguration;

        public void SetTarget(SignTargetUI toConfigure)
        {
            ResponseObject = toConfigure;
            Configuring = toConfigure.Target;
            InitialConfiguration = Configuring.CurrentConfiguration();
            ResetView();
        }


        void ResetView()
        {
            Elements = new List<EditElement>();
            panel1.Controls.Clear();

            foreach(SignComponent c in InitialConfiguration.Components)
            {
                AddElement(new EditElement(this, c));
            }
            panel1.Invalidate();
            ConfigurationChange();
        }

        void AddElement(EditElement e)
        {
            lock (Elements)
            {
                Elements.Add(e);
                panel1.Controls.Add(e.ImageTile);
            }
        }

        internal void RemoveElement(EditElement e)
        {
            lock (Elements)
            {
                Elements.Remove(e);
                panel1.Controls.Remove(e.ImageTile);
            }
        }

        void UpdateImages()
        {
            lock (Elements)
            {
                foreach (EditElement e in Elements)
                {
                    e.ImageSection = new Bitmap(e.Location.Width, e.Location.Height);
                    Graphics g = Graphics.FromImage(e.ImageSection);
                    g.Clear(Color.DarkBlue);
                    g.DrawImageUnscaled(CurrentRender, -e.Location.X, -e.Location.Y);
                    e.ImageTile.Image = e.ImageSection;
                    e.ImageTile.Invalidate();
                }
            }
        }

        public void ConfigurationChange()
        {
            SignConfiguration newConfiguration = new SignConfiguration(Elements.Select(e => e.Location).ToArray());
            Configuring.ApplyConfiguration(newConfiguration);
            SetIdentify(checkBox1.Checked);
            ParentWindow.UpdateConfiguration(ResponseObject);
        }


        void AddNewElement(int width, int height)
        {
            SignComponent c = new SignComponent() { Width = width, Height = height };
            EditElement e = new EditElement(this, c);

            // Find a new grid-aligned location that doesn't overlap with any other element
            for (int y = 0; y < MaxY; y += height)
            {
                for (int x = 0; x < MaxX; x += width)
                {
                    e.Location.X = x;
                    e.Location.Y = y;
                    if (!e.Collides()) break;
                }
                if (!e.Collides()) break;
            }

            if(e.Collides())
            {
                // Silently fail.
                return;
            }

            e.SyncLocation();
            AddElement(e);
            ConfigurationChange();
        }

        void SetIdentify(bool enable)
        {
            ResponseObject.UseConfigureDisplay = enable;
            if(enable)
            {
                // Generate configuration image;
                SignRender r = new SignRender();
                r.SetConfiguration(ResponseObject.Target.CurrentConfiguration());

                r.Clear();

                lock(Elements)
                {
                    int index = 1;
                    foreach(EditElement e in Elements)
                    {
                        string text = index.ToString();

                        SizeF sz = r.MeasureText(12, text);

                        r.DrawTextAbsolute(12, text, Color.White,
                            e.Location.X + (e.Location.Width - sz.Width) / 2,
                            e.Location.Y + (e.Location.Height - sz.Height) / 2);

                        index++;
                    }
                }

                UpdateFrameInternal(r.SignOutput);
                ResponseObject.Target.SendImage(r.SignOutput);
            }
        }


        private void button1_Click(object sender, EventArgs e)
        {
            // Add 32x32
            AddNewElement(32, 32);
        }

        private void button2_Click(object sender, EventArgs e)
        {
            // Add 32x16
            AddNewElement(32, 16);
        }

        private void button5_Click(object sender, EventArgs e)
        {
            // Rotate
        }

        private void checkBox1_CheckedChanged(object sender, EventArgs e)
        {
            // Identify
            SetIdentify(checkBox1.Checked);
        }

        private void button3_Click(object sender, EventArgs e)
        {
            // Reset
            ResetView();
        }

        private void button4_Click(object sender, EventArgs e)
        {
            // Accept
            ParentWindow.CompleteConfiguration(ResponseObject);
            Hide();
        }

        private void SignTargetConfigure_FormClosing(object sender, FormClosingEventArgs e)
        {

        }


    }

    class EditElement
    {
        public EditElement(SignTargetConfigure container, SignComponent c)
        {
            Parent = container;
            Location = c;
            ImageTile = new PictureBox();
            ImageSection = new Bitmap(Location.Width, Location.Height);
            ImageTile.Image = ImageSection;

            int scale = SignTargetConfigure.ScaleFactor;

            ImageTile.Width = Location.Width * scale;
            ImageTile.Height = Location.Height * scale;
            ImageTile.Location = new Point(Location.X * scale, Location.Y * scale);

            ImageTile.SizeMode = PictureBoxSizeMode.StretchImage;
            ImageTile.Cursor = Cursors.SizeAll;

            ImageTile.MouseDown += ImageTile_MouseDown;
            ImageTile.MouseMove += ImageTile_MouseMove;
            ImageTile.MouseUp += ImageTile_MouseUp;
        }

        bool Dragging;
        int MouseX, MouseY;

        void ImageTile_MouseDown(object sender, MouseEventArgs e)
        {
            MouseX = e.X;
            MouseY = e.Y;
            if(e.Button == MouseButtons.Left)
            {
                Dragging = true;
                ImageTile.Capture = true;
            }
            if(e.Button == MouseButtons.Right)
            {
                // Delete this element.
                Parent.RemoveElement(this);
                Parent.ConfigurationChange();
            }
        }

        void ImageTile_MouseUp(object sender, MouseEventArgs e)
        {
            Dragging = false;
            ImageTile.Capture = false;
        }

        void ImageTile_MouseMove(object sender, MouseEventArgs e)
        {
            int scale = SignTargetConfigure.ScaleFactor;
            int maxx = SignTargetConfigure.MaxX;
            int maxy = SignTargetConfigure.MaxY;
            int grid = 8;
            int minMove = grid * scale * 3 / 4;
            if (Dragging)
            {
                int dx = e.X - MouseX;
                int dy = e.Y - MouseY;

                int movex = 0;
                int movey = 0;

                if (Math.Abs(dx) > minMove)
                {
                    movex = (int)Math.Round((float)dx / (grid * scale)) * grid;
                }
                if (Math.Abs(dy) > minMove)
                {
                    movey = (int)Math.Round((float)dy / (grid * scale)) * grid;
                }

                // Clip to edges
                if (Location.X + movex < 0)
                {
                    movex = -Location.X;
                }
                if (Location.Y + movey < 0)
                {
                    movey = -Location.Y;
                }

                if (Location.X + movex + Location.Width > maxx)
                {
                    movex = maxx - Location.X - Location.Width;
                }
                if (Location.Y + movey + Location.Height > maxy)
                {
                    movey = maxy - Location.Y - Location.Height;
                }

                SignComponent fallback = Location;
                // Perform move
                Location.X += movex;
                Location.Y += movey;

                if(Collides())
                {
                    // Don't allow overlapping tiles
                    Location = fallback;
                }
                else
                {
                    ImageTile.Location = new Point(Location.X * scale, Location.Y * scale);
                    Parent.ConfigurationChange();
                }

            }
        }

        public bool Collides()
        {
            foreach(EditElement e in Parent.Elements)
            {
                if (e == this) continue;

                if (e.Location.Overlaps(Location))
                    return true;
            }
            return false;
        }
        public void SyncLocation()
        {
            int scale = SignTargetConfigure.ScaleFactor;
            ImageTile.Location = new Point(Location.X * scale, Location.Y * scale);
        }

        public SignTargetConfigure Parent;
        public PictureBox ImageTile;
        public Bitmap ImageSection;
        public SignComponent Location;
    }
}
