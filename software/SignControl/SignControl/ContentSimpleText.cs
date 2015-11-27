using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SignControl
{
    [SignContent("Simple Text")]
    class ContentSimpleText : ISignContent
    {
        public string Text = "Hello World!";
        public ContentSimpleText()
        {

        }

        public IEnumerable<SignElement> GetElements()
        {
            yield return new SignTextElement(Text);
        }
    }
}
