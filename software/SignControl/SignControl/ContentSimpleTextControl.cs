using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace SignControl
{
    public partial class ContentSimpleTextControl : UserControl, ISignContentControl
    {
        public ContentSimpleTextControl()
        {
            InitializeComponent();
            textBox1.TextChanged += textBox1_TextChanged;
        }

        bool SuppressChange = true;
        void textBox1_TextChanged(object sender, EventArgs e)
        {
            if(!SuppressChange)
            {
                Target.Text = textBox1.Text;
                SendChange();
            }
        }

        ContentSimpleText Target;

        public void BindToContent(ISignContent content)
        {
            Target = (ContentSimpleText)content; // throw on error

            textBox1.Text = Target.Text;
            SuppressChange = false;
        }
        public event SignContentNotify ContentChange;
        void SendChange()
        {
            Target.HasUpdate = true;
            SignContentNotify n = ContentChange;
            if (n != null)
                n(Target);
        }

        private void button1_Click(object sender, EventArgs e)
        {
            // Todo.
        }

    }
}
