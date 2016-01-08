using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SignControl
{
    class GeneralBackgrounds
    {

    }

    class GeneralBackgroundAttribute : Attribute
    {
    }


    class ColorBackground : SignBackground
    {
        public Color BackgroundColor;
        public override void Render()
        {
            g.Clear(BackgroundColor);
        }
    }

}
