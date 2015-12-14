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

        SignTargetConfigure ConfigWindow;

        List<SignTargetUI> Targets;
        List<SignElementUI> Elements;
        public SignControl()
        {
            InitializeComponent();
            Targets = new List<SignTargetUI>();
            Elements = new List<SignElementUI>();
            Animate = new SignAnimate();
            Animate.FrameComplete += Animate_FrameComplete;

            comboBox1.Items.Add("Sign Preview");
            comboBox1.SelectedIndex = 0;

            foreach(SignContentType t in SignContentFactory.EnumerateContentTypes())
            {
                comboBox2.Items.Add(t.Name);
            }
            comboBox2.SelectedIndex = 0;

            listBox1.Items.Add("Global Configuration");

            // Add some things for test purproses.
            AddSignTarget(new SignPreview());
            AddSignElement(SignContentFactory.GetFromName("Simple Text"));
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
            if(ConfigWindow != null)
            {
                if(ConfigWindow.Visible)
                {
                    ConfigWindow.UpdateFrame(a.Render.SignOutput);
                }
            }
        }

        private void button1_Click(object sender, EventArgs e)
        {
            // Adding a sign target
            AddSignTarget(new SignPreview());
        }

        private void button2_Click(object sender, EventArgs e)
        {
            // Add a sign element
            AddSignElement(SignContentFactory.GetFromName((string)comboBox2.SelectedItem));
        }

        void AddSignElement(SignContentType e)
        {
            SignElementUI se = new SignElementUI();
            se.ContentType = e;
            se.Content = SignContentFactory.Create(e);
            try
            {
                se.ContentControl = SignContentFactory.CreateControl(e);
                se.ContentControl.BindToContent(se.Content);
                se.ContentControl.ContentChange += ContentControl_ContentChange;
            }
            catch
            {
                se.ContentControl = null; // If there are errors, don't use the UI. (allow controls without UI)
            }

            ISignContent[] newElements;
            lock(Elements)
            {
                Elements.Add(se);

                listBox1.Items.Add(se.Content.Summary);

                newElements = Elements.Select(i => i.Content).ToArray();
            }

            Animate.SetContent(newElements);
        }

        bool SuppressListboxChange = false;
        void ContentControl_ContentChange(ISignContent content)
        {
            // Figure out which element this was and update the listbox text.
            for(int i=0;i<Elements.Count;i++)
            {
                if(Elements[i].Content == content)
                {
                    SuppressListboxChange = true;
                    listBox1.Items[i + 1] = content.Summary;
                    SuppressListboxChange = false;
                    break;
                }
            }
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
            if(ConfigWindow == null)
            {
                ConfigWindow = new SignTargetConfigure(this);
                ConfigWindow.FormClosing += ConfigWindow_FormClosing;
            }
            ConfigWindow.SetTarget(targetUI);
            ConfigWindow.Show();
        }

        void ConfigWindow_FormClosing(object sender, FormClosingEventArgs e)
        {
            if(ConfigWindow == sender)
            {
                CompleteConfiguration(ConfigWindow.ResponseObject);
                ConfigWindow = null;
            }
        }

        public void UpdateConfiguration(SignTargetUI target)
        {
            // Apply configuration to all other displays for now. Maybe support multiple configurations in the future.
            SignConfiguration c = target.Target.CurrentConfiguration();
            foreach(SignTargetUI t in Targets)
            {
                if(t != target)
                {
                    t.Target.ApplyConfiguration(c);
                }
            }
            Animate.SetConfiguration(c);
        }

        public void CompleteConfiguration(SignTargetUI target)
        {
            target.UseConfigureDisplay = false;
        }

        private void listBox1_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (SuppressListboxChange) return;
            ccPanel.Controls.Clear();
            int index = listBox1.SelectedIndex;
            if (index < 0) return;
            if (index == 0)
            {
                // global state
            }
            else
            {
                // Setup the panel from a given control.
                SignElementUI se = Elements[index - 1];
                if (se.ContentControl != null)
                {
                    Control c = se.ContentControl as Control;
                    if (c != null)
                    {
                        c.Location = Point.Empty;
                        c.Width = ccPanel.Width;
                        c.Height = ccPanel.Height;
                        ccPanel.Controls.Add(c);
                        c.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
                    }
                }
            }
        }



    }

    public class SignElementUI
    {
        public SignContentType ContentType;
        public ISignContent Content;
        public ISignContentControl ContentControl;


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
