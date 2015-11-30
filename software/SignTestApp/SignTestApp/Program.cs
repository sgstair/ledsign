using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using SignTestInterface;

namespace SignTestApp
{
    class Program
    {
        static void Main(string[] args)
        {
            // Enter into a test loop
            TestLoop t = new TestLoop();
            t.Run();
        }
    }


    class TestLoop
    {
        const int StatusCount = 128; // Keep a history for debugging
        const int StableCount = 5; // About 0.5 second

        enum TestState
        {
            WaitForDevice,
            WaitDeviceLeave,
            SoftOn,
            PowerOn,
            CheckFlash,
        }


        SignTest Dev;
        Queue<SignTestStatus> RecentStatus;
        TestState CurrentState, NextState;
        bool LastPrintedStatus;
        int LastLineLength;

        void Reset()
        {
            Dev.SetMode(SignTest.DeviceMode.Off);
            LastPrintedStatus = false;
            LastLineLength = 0;
            RecentStatus = new Queue<SignTestStatus>();
            CurrentState = TestState.WaitForDevice;
        }

        void UpdateStatus(string additionalText)
        {
            SignTestStatus newStatus = Dev.ReadStatus();

            RecentStatus.Enqueue(newStatus);
            if (RecentStatus.Count > StatusCount)
                RecentStatus.Dequeue();

            LastPrintedStatus = true;
            string text = string.Format("[{0}] {1} {2}", DateTime.Now, newStatus.ToString(), additionalText);

            int textActualLength = text.Length;
            if(text.Length < LastLineLength)
            {
                text += new string(' ', LastLineLength - text.Length);
            }
            LastLineLength = textActualLength;

            Console.Write("\r" + text);
        }
        void WriteText(string text, params object[] args)
        {
            if (args.Length != 0)
                text = string.Format(text, args);

            if (LastPrintedStatus)
                Console.WriteLine();

            LastPrintedStatus = false;

            Console.WriteLine("[{0}] {1}", DateTime.Now, text);
        }

        delegate bool SignStable(SignTestStatus status);
        bool IsStable(SignStable test, int count = StableCount)
        {
            if (RecentStatus.Count < count)
                return false;

            return RecentStatus.Skip(RecentStatus.Count-count).Where(s => test(s)).Count() == count;
        }
            

        public void Run()
        {
            Dev = new SignTest(SignTest.Enumerate().First());
            Reset();
            while(true)
            {
                if(System.Diagnostics.Debugger.IsAttached)
                {
                    // Run without exception handling in the debugger.
                    Loop();
                }
                else
                {
                    try {

                        Loop();
                    
                    } catch(Exception ex)
                    {
                        Console.WriteLine();
                        Console.WriteLine("Exception!");
                        Console.WriteLine(ex.ToString());
                        Thread.Sleep(2000);
                        Console.WriteLine("Restarting...");
                        Reset();
                    }
                }

                // Check for some control characters
                if (Console.KeyAvailable)
                {
                    ConsoleKeyInfo k = Console.ReadKey(true);

                    switch (char.ToLower(k.KeyChar))
                    {
                        case '?':
                        case 'h':
                            WriteText("Special keys: 'x' Exit, 'r' Reprogram test board");
                            break;

                        case 'x':
                            // Clean up and exit
                            Reset();
                            return;

                        case 'r':
                            Reset();
                            Dev.Reprogram();
                            return;

                    }
                }


                Thread.Sleep(100);
            }


        }

        public void Loop()
        {
            NextState = CurrentState;
            UpdateStatus(CurrentState.ToString());

            switch(CurrentState)
            {
                case TestState.WaitForDevice:
                    if(IsStable(s => s.Sense))
                    {
                        // Sensed a device.
                        NextState = TestState.SoftOn;
                        Dev.SetMode(SignTest.DeviceMode.SoftOn);
                    }
                    break;

                case TestState.WaitDeviceLeave:
                    if (IsStable(s => s.DeviceGone, StableCount)) 
                    {
                        NextState = TestState.WaitForDevice;
                        Dev.SetMode(SignTest.DeviceMode.Off); // Ensure that it's off.
                    }
                    break;

                case TestState.SoftOn:
                    break;
            }

            // Did the device disappear?
            if (CurrentState != TestState.WaitForDevice)
            {
                if (IsStable(s => s.DeviceGone, StableCount * 2))
                {
                    WriteText("Unexpected device loss.");
                    NextState = TestState.WaitForDevice;
                    Dev.SetMode(SignTest.DeviceMode.Off); // Ensure that it's off.
                }
            }


            if(NextState != CurrentState)
            {
                WriteText("State change from {0} => {1}", CurrentState, NextState);
                CurrentState = NextState;
            }
        }



    }

}
