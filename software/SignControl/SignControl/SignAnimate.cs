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

        public ISignContent[] ContentSources;
        SignElement[] ContentElements;

        Timer FrameTimer;

        // Global rate information - todo: make tweakable.
        public int FramesPerScroll = 1;
        public int HoldDelay = 30;
        public int RecycleDelay = 30;
        public int ElementSpacing = 5;

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
            }
        }

        public void SetContent(ISignContent[] sources)
        {
            SignElement[] newElements = sources.SelectMany((s) => s.GetElements()).ToArray();
            lock(this)
            {
                ContentSources = sources;
                ContentElements = newElements;
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


        int AnimateFirstElement;
        int AnimateElementOffset;
        int DelayTime;
        void ResetAnimation()
        {
            AnimateFirstElement = 0;
            AnimateElementOffset = 0;
            DelayTime = 0;
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
                    foreach (SignElement e in ContentElements)
                    {
                        e.SetContext(Render);
                    }

                    // Advance anmiation
                    if(DelayTime > 0)
                    {
                        DelayTime--;
                    }
                    else
                    {
                        if(AnimateFirstElement >= ContentElements.Length)
                        {
                            DelayTime = RecycleDelay;
                            AnimateFirstElement = 0;
                            AnimateElementOffset = 0;
                        }
                        else
                        {
                            // Scrolling
                            SignElement firstElement = ContentElements[AnimateFirstElement];
                            AnimateElementOffset--;
                            int elementLocation = Render.Configuration.Width + AnimateElementOffset;
                            if (elementLocation + firstElement.Width < 0)
                            { 
                                // Advance to next element
                                AnimateFirstElement++;
                                AnimateElementOffset += firstElement.Width + ElementSpacing;
                            }

                            DelayTime = FramesPerScroll - 1;
                        }
                    }

                    // Render
                    ElementAnimation animMode = ElementAnimation.None;
                    int offset = 0;
                    for (int i = AnimateFirstElement; i < ContentElements.Length; i++)
                    {
                        SignElement curElement = ContentElements[i];
                        if (animMode == ElementAnimation.None)
                            animMode = curElement.Animation;

                        if (animMode != curElement.Animation)
                            break;

                        Render.ElementXOffset = Render.Configuration.Width + AnimateElementOffset + offset;
                        Render.ElementYOffset = 0;

                        if (Render.ElementXOffset >= Render.Configuration.Width)
                            break;

                        curElement.Render(Render);

                        offset += curElement.Width + ElementSpacing;
                        
                    }

                }                
                SendFrameComplete();


                if (ContentElements != null)
                {
                    // Rebuild content list if necessary. Do this after rendering to reduce jitter. 
                    // May not be that important. (measure later)
                    bool needRebuild = false;
                    foreach (ISignContent sc in ContentSources)
                    {
                        if (sc.HasUpdate)
                            needRebuild = true;
                    }

                    if (needRebuild)
                    {
                        ContentElements = ContentSources.SelectMany((s) => s.GetElements()).ToArray();

                    }
                }
            }
        }

    }
}
