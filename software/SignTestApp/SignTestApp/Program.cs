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

            if (args.Length >= 1)
            {
                string filename = args[0];
                t.SetFpgaFilename(filename);
            }

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
            ProgramFpga,
            BootFpga,
            TestFpga
        }


        SignTest Dev;
        Queue<SignTestStatus> RecentStatus;
        TestState CurrentState, NextState;
        bool LastPrintedStatus;
        int LastLineLength;

        public void SetFpgaFilename(string filename)
        {
            byte[] fpgaFile = System.IO.File.ReadAllBytes(filename);
            FpgaProgram = fpgaFile;
        }
        public byte[] FpgaProgram;

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
            if (text.Length < LastLineLength)
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

        void HexDump(int address, byte[] data)
        {
            const int rowSize = 16;
            int offset = 0;
            while(offset < data.Length)
            {
                byte[] row = data.Skip(offset).Take(rowSize).ToArray();
                string row1 = string.Join(" ", row.Select(b => b.ToString("x2")));
                string row2 = string.Join("", row.Select(b => b > 31 ? (char)b : '.'));
                if (row.Length < rowSize) row1 += new string(' ', (rowSize - row.Length) * 3);
                WriteText("{0:x8}: {1} {2}", address, row1, row2);
                offset += rowSize;
                address += rowSize;
            }
        }


        delegate bool SignStable(SignTestStatus status);
        bool IsStable(SignStable test, int count = StableCount)
        {
            if (RecentStatus.Count < count)
                return false;

            return RecentStatus.Skip(RecentStatus.Count - count).Where(s => test(s)).Count() == count;
        }

        bool CompareBytes(byte[] a, int aStart, byte[] b, int bStart, int length)
        {
            for(int i=0;i<length;i++)
            {
                if (a[aStart + i] != b[bStart + i])
                    return false;
            }
            return true;
        }


        public void Run()
        {
            Dev = new SignTest(SignTest.Enumerate().First());
            Reset();
            while (true)
            {
                if (System.Diagnostics.Debugger.IsAttached)
                {
                    // Run without exception handling in the debugger.
                    Loop();
                }
                else
                {
                    try
                    {
                        Loop();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine();
                        Console.WriteLine("Exception!");
                        Console.WriteLine(ex.ToString());

                        try
                        {
                            Dev.SetLed(false, true);
                        } 
                        catch
                        {

                        }
                        
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
                            WriteText("Special keys: 'x' Exit, 'r' Reprogram test board, <space> reprogram current board.");
                            break;

                        case 'x':
                            // Clean up and exit
                            WriteText("'x' pressed, exiting.");
                            Reset();
                            return;

                        case 'r':
                            WriteText("'r' pressed, putting test board into reprogramming mode.");
                            Reset();
                            Dev.Reprogram();
                            return;

                        case ' ':
                            WriteText("<Space> pressed, resetting test system state.");
                            Reset();
                            break;
                    }
                }


                Thread.Sleep(100);
            }


        }

        public void Loop()
        {
            NextState = CurrentState;
            UpdateStatus(CurrentState.ToString());

            switch (CurrentState)
            {
                case TestState.WaitForDevice:
                    Dev.SetLed(false, false);
                    if (IsStable(s => s.Sense))
                    {
                        // Sensed a device.
                        NextState = TestState.SoftOn;
                        Dev.SetMode(SignTest.DeviceMode.SoftOn);
                    }
                    break;

                case TestState.WaitDeviceLeave:
                    if (IsStable(s => s.DeviceGone))
                    {
                        NextState = TestState.WaitForDevice;
                        Dev.SetMode(SignTest.DeviceMode.Off); // Ensure that it's off.
                    }
                    if(Dev.GetButton())
                    {
                        // If button is pressed, rerun the process for the currently attached device.
                        WriteText("Button pressed, restarting process");
                        NextState = TestState.WaitForDevice;
                    }
                    break;

                case TestState.SoftOn:
                    if (IsStable(s => s.SoftOnOk))
                    {
                        NextState = TestState.PowerOn;
                        Dev.SetMode(SignTest.DeviceMode.On);
                    }
                    break;

                case TestState.PowerOn:
                    if (IsStable(s => s.PowerOk))
                    {
                        // Higher power standards have been met.
                        NextState = TestState.CheckFlash;
                    }
                    break;

                case TestState.CheckFlash:
                    // Sanity test flash
                    Dev.SetMode(SignTest.DeviceMode.FlashSpi);

                    UInt32 flashId = Dev.FlashReadId();
                    WriteText("Flash ID: {0:x8}", flashId);


                    byte[] checkData = Dev.FlashRead(0, 128);
                    // HexDump(0, checkData);

                    // Confirm whether flash contains the latest program
                    if(FpgaProgram == null)
                    {
                        WriteText("Skipping flash contents check.");
                        NextState = TestState.BootFpga;
                        break;
                    }


                    if(!CompareBytes(checkData,0,FpgaProgram,0,checkData.Length))
                    {
                        WriteText("Quick check shows we need to reprogram the FPGA.");
                        NextState = TestState.ProgramFpga;
                        break;
                    }
                    else
                    {
                        WriteText("Checking full FPGA program...");
                    }

                    checkData = Dev.FlashRead(0, FpgaProgram.Length);

                    if (!CompareBytes(checkData, 0, FpgaProgram, 0, checkData.Length))
                    {
                        WriteText("Full check shows we need to reprogram the FPGA.");
                        NextState = TestState.ProgramFpga;
                        break;
                    }

                    WriteText("Fpga program is correct.");
                    NextState = TestState.BootFpga;
                    break;


                case TestState.ProgramFpga:
                    WriteText("Erasing flash sectors...");
                    Dev.FlashEraseRegion(0, FpgaProgram.Length);
                    WriteText("Programming flash...");
                    Dev.FlashWrite(0, FpgaProgram);

                    NextState = TestState.BootFpga;
                    break;

                case TestState.BootFpga:
                    try
                    {
                        Dev.SetMode(SignTest.DeviceMode.FpgaActive);
                        Dev.SetLed(true, false);
                        WriteText("Fpga Booted!");
                    }
                    catch(Exception ex)
                    {
                        WriteText("Fpga Failed to boot.");
                        Dev.SetLed(false, true);
                        WriteText(ex.ToString());
                    }
                    NextState = TestState.WaitDeviceLeave;
                    break;

                case TestState.TestFpga:
                    WriteText("Nothing to do currently.");
                    NextState = TestState.WaitDeviceLeave;
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


            if (NextState != CurrentState)
            {
                WriteText("State change from {0} => {1}", CurrentState, NextState);
                CurrentState = NextState;
            }
        }



    }

}
