using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using SignTestInterface;
using winusbdotnet;

namespace SignControl
{
    class TargetTestBoard : ISignTarget
    {
        public TargetTestBoard()
        {
            TestBoard = null;
            foreach(var dev in SignTest.Enumerate())
            {
                try
                {
                    TestBoard = new SignTest(dev);
                    break;
                }
                catch { }
            }
            if (TestBoard == null)
                throw new Exception("Unable to attach to a Sign Test board.");


            SignComponent[] c = new SignComponent[1];
            c[0] = new SignComponent() { X = 0, Y = 0, Width = 32, Height = 32 };
            CurrentConfig = new SignConfiguration(c);

            // Initialize test board.

            TestBoard.SetMode(SignTest.DeviceMode.On);
            TestBoard.SetMode(SignTest.DeviceMode.FpgaActive);

        }
        SignTest TestBoard;

        SignConfiguration CurrentConfig;

        public bool SupportsConfiguration(SignConfiguration configuration)
        {
            return true;
        }
        public void ApplyConfiguration(SignConfiguration configuration)
        {
            CurrentConfig = configuration;
        }
        public void SendImage(Bitmap signImage)
        {
            SignConfiguration config = CurrentConfig;

            // For each element in the configuration, render it.
            for (int i = 0; i < config.Components.Length; i++ )
            {
                SignComponent c = config.Components[i];
                uint[] elementData = new uint[32 * 32];
                
                for(int y=0;y<32;y++)
                {
                    for(int x=0;x<32;x++)
                    {
                        elementData[x + y * 32] = (uint)signImage.GetPixel(x + c.X, y + c.Y).ToArgb();
                    }
                }

                TestBoard.SendImage32x32(i, elementData);
            }
        }
        public SignConfiguration CurrentConfiguration()
        {
            return CurrentConfig;
        }

        public string SignName
        {
            get
            {
                return "Test Board";
            }
        }

    }
}
