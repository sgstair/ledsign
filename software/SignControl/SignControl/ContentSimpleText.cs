using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SignControl
{
    [SignContent("Simple Text")]
    class ContentSimpleText : ISignContent
    {
        public string Text = "Hello World!";
        public Color TextColor;
        public ContentSimpleText()
        {
            TextColor = Color.White;
        }

        public bool HasUpdate { get; set; }

        public IEnumerable<SignElement> GetElements()
        {
            HasUpdate = false;
            yield return new SignTextElement(Text, TextColor);
        }

        public string Summary
        {
            get
            {
                return String.Format("Simple Text: {0}", Text);
            }
        }
    }
}
