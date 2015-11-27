using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SignControl
{
    class SignAnimate
    {
        public delegate void SignNotification(SignAnimate a);

        public event SignNotification FrameComplete;

        public SignRender Render;
        bool UpdateRenderContext;

        public ISignContent[] ContentSources;
        SignElement[] ContentElements;

        Timer FrameTimer;

        public SignAnimate()
        {
            Render = null;
            FrameTimer = new Timer(FrameTick);
            SetAnimationRate(30);
        }

        public void SetAnimationRate(float fps)
        {
            lock (this)
            {
                TimeSpan period = TimeSpan.FromSeconds(1 / fps);
                FrameTimer.Change(period, period);
            }
        }

        public void SetConfiguration(SignConfiguration c)
        {
            lock(this)
            {
                if(Render == null)
                {
                    Render = new SignRender();
                }
                Render.SetConfiguration(c);
                UpdateRenderContext = true;
            }
        }

        public void SetContent(ISignContent[] sources)
        {
            SignElement[] newElements = sources.SelectMany((s) => s.GetElements()).ToArray();
            lock(this)
            {
                ContentSources = sources;
                ContentElements = newElements;
                UpdateRenderContext = true;
            }
        }

        void SendFrameComplete()
        {
            SignNotification n = FrameComplete;
            if(n != null)
            {
                n(this);
            }
        }

        void FrameTick(object context)
        {
            lock (this)
            {
                if (Render == null)
                    return;

                Render.Clear();

                if (ContentElements != null)
                {
                    if (UpdateRenderContext)
                    {
                        foreach (SignElement e in ContentElements)
                        {
                            e.SetContext(Render);
                        }
                    }

                    for (int i = 0; i < ContentElements.Length; i++)
                    {
                        Render.ElementXOffset = 0;
                        Render.ElementYOffset = 0;

                        ContentElements[i].Render(Render);

                    }

                }                
                SendFrameComplete();
            }
        }

    }
}
