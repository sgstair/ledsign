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
    public partial class SignControl : Form
    {
        SignAnimate Animate;

        List<SignTargetUI> Targets;
        List<ISignContent> Elements;
        public SignControl()
        {
            InitializeComponent();
            Targets = new List<SignTargetUI>();
            Elements = new List<ISignContent>();
            Animate = new SignAnimate();
            Animate.FrameComplete += Animate_FrameComplete;

            comboBox1.Items.Add("Sign Preview");
            comboBox1.SelectedIndex = 0;

            foreach(SignContentType t in SignContentFactory.EnumerateContentTypes())
            {
                comboBox2.Items.Add(t.Name);
            }
            comboBox2.SelectedIndex = 0;


            // Add some things for test purproses.
            AddSignTarget(new SignPreview());
            AddSignElement(SignContentFactory.Create("Simple Text"));
        }

        void Animate_FrameComplete(SignAnimate a)
        {
            lock (Targets)
            {
                foreach (SignTargetUI st in Targets)
                {
                    if (!st.UseConfigureDisplay)
                    {
                        st.Target.SendImage(a.Render.SignOutput);
                    }
                }
            }
        }

        private void tableLayoutPanel1_Paint(object sender, PaintEventArgs e)
        {

        }

        private void button1_Click(object sender, EventArgs e)
        {
            // Adding a sign target
            AddSignTarget(new SignPreview());
        }

        private void button2_Click(object sender, EventArgs e)
        {
            // Add a sign element
            AddSignElement(SignContentFactory.Create((string)comboBox2.SelectedItem));
        }

        void AddSignElement(ISignContent e)
        {
            ISignContent[] newElements;
            lock(Elements)
            {
                Elements.Add(e);

                listBox1.Items.Add(e.ToString());

                newElements = Elements.ToArray();
            }

            Animate.SetContent(newElements);
        }



        void AddSignTarget(ISignTarget target)
        {
            SignTargetUI targetUI = new SignTargetUI(this);

            targetUI.uiPanel.Width = flowLayoutPanel1.Width;
            flowLayoutPanel1.Controls.Add(targetUI.uiPanel);
            flowLayoutPanel1.Controls.SetChildIndex(targetUI.uiPanel, 0);

            targetUI.Label = target.SignName;

            if(target is SignPreview)
            {
                // Mirror the last non-preview configuration.
                ((SignPreview)target).Show();
                //this.BringToFront(); // not sure if I like this.
            }
            targetUI.Target = target;



            lock (Targets)
            {
                if (Targets.Count == 0)
                    Animate.SetConfiguration(target.CurrentConfiguration());
                    
                Targets.Add(targetUI);
            }
        }

        internal void RemoveSignTarget(SignTargetUI targetUI)
        {
            lock(Targets)
            {
                Targets.Remove(targetUI);
            }
            flowLayoutPanel1.Controls.Remove(targetUI.uiPanel);
            if(targetUI.Target is SignPreview)
            {
                ((SignPreview)targetUI.Target).Close();
            }
        }

        internal void ConfigureSignTarget(SignTargetUI targetUI)
        {

        }

        public void CompleteConfiguration(SignTargetUI target)
        {
            target.UseConfigureDisplay = false;
            // Apply configuration to all other displays for now. Maybe support multiple configurations in the future.
        }



    }

    public class SignTargetUI
    {
        public ISignTarget Target;

        public SignControl Parent;

        public Panel uiPanel;
        public Button btnConfigure, btnRemove;
        public Label lblText;

        public bool UseConfigureDisplay;

        public SignTargetUI(SignControl owner)
        {
            Parent = owner;

            uiPanel = new Panel();
            btnConfigure = new Button();
            btnRemove = new Button();
            lblText = new Label();

            uiPanel.Anchor = AnchorStyles.Left | AnchorStyles.Right;
            uiPanel.BorderStyle = BorderStyle.FixedSingle;

            uiPanel.Controls.Add(lblText);
            uiPanel.Controls.Add(btnConfigure);
            uiPanel.Controls.Add(btnRemove);

            btnConfigure.Text = "Configure";
            btnRemove.Text = "Remove";

            lblText.Location = new Point(5, 5);
            lblText.Width = 300;
            btnConfigure.Location = new Point(lblText.Location.X + lblText.Width + 5, 5);
            btnRemove.Location = new Point(btnConfigure.Location.X + btnConfigure.Width + 5, 5);
            uiPanel.Height = btnConfigure.Height + 8;

            btnConfigure.Click += btnConfigure_Click;
            btnRemove.Click += btnRemove_Click;

        }

        void btnRemove_Click(object sender, EventArgs e)
        {
            Parent.RemoveSignTarget(this);
        }

        void btnConfigure_Click(object sender, EventArgs e)
        {
            Parent.ConfigureSignTarget(this);   
        }

        public string Label
        {
            get { return lblText.Text; }
            set { lblText.Text = value; }
        }


    }
}
