﻿using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SignControl
{
    public enum ElementAnimation
    {
        None,
        ScrollLeft,

    }

    public class SignBackground
    {
        protected Bitmap Bmp;
        protected Graphics g;
        public void Render(SignRender r)
        {
            r.PrepareBitmapBackground(ref Bmp);
            g = Graphics.FromImage(Bmp);
            Render();
            r.DrawBackground(Bmp);
        }

        public virtual void Render()
        {
            throw new Exception("Sign Background needs to implement render and not call the base.");
        }
    }

    public class SignElement
    {
        public int Width { get; protected set; }

        public ElementAnimation Animation = ElementAnimation.ScrollLeft;

        public virtual void SetContext(SignRender r)
        {
        }

        public virtual void Render(SignRender r)
        {
        }
    }

    public class SignTextElement : SignElement
    {
        public string Text;
        public Color TextColor;
        public SignTextElement(string text)
        {
            Text = text;
            TextColor = Color.White;
        }
        public SignTextElement(string text, Color c)
        {
            Text = text;
            TextColor = c;
        }

        public override void SetContext(SignRender c)
        {
            int height = c.Configuration.Height - 3;
            SizeF sz = c.MeasureText(height, Text);
            Width = (int)sz.Width;
        }
        public override void Render(SignRender r)
        {
            int height = r.Configuration.Height - 3;
            r.DrawText(height, Text, TextColor);
        }

    }
}
