using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using winusbdotnet;

namespace SignTestInterface
{
    public class SignTest
    {
        WinUSBDevice Device;

        public static IEnumerable<WinUSBEnumeratedDevice> Enumerate()
        {
            return WinUSBDevice.EnumerateDevices(new Guid("b86d3dd6-c9d8-4401-959b-efbbd9bf1f3c"));
        }

        public SignTest(WinUSBEnumeratedDevice deviceInfo)
        {
            Device = new WinUSBDevice(deviceInfo);
        }


        enum DeviceRequest
        {
            Reprogram = 0x02,

            ReadStatus = 0x10,
            SetMode = 0x11,
            SetLed = 0x12,

            ScratchPad = 0x18,
            ClearScratchPad = 0x19, // Set to all FF

            SpiFlash = 0x1A,
            SpiFpga = 0x1B,

            FlashEraseSector = 0x20,
            FlashEraseBlock = 0x21,
            FlashRead = 0x22,
            FlashProgram = 0x23,
            FlashReadId = 0x24,

            FlashCrc32 = 0x28, // 64k block

        }

        public enum DeviceMode
        {
            Off = 0,
            SoftOn = 1,
            On = 2,
            FlashSpi = 3,
            FpgaActive = 4
        }

        public const int FlashSectorSize = 4096;
        public const int FlashBlockSize = 65536;


        byte[] VendorRequestIn(DeviceRequest request, ushort value, ushort index, ushort length)
        {
            byte requestType = WinUSBDevice.ControlRecipientDevice | WinUSBDevice.ControlTypeVendor;


            return Device.ControlTransferIn(requestType, (byte)request, value, index, length);
        }
        void VendorRequestOut(DeviceRequest request, ushort value = 0, ushort index = 0, byte[] data = null)
        {
            byte requestType = WinUSBDevice.ControlRecipientDevice | WinUSBDevice.ControlTypeVendor;
            Device.ControlTransferOut(requestType, (byte)request, value, index, data);
        }


        public void Reprogram()
        {
            VendorRequestOut(DeviceRequest.Reprogram);
        }

        public SignTestStatus ReadStatus()
        {
            byte[] data = VendorRequestIn(DeviceRequest.ReadStatus, 0, 0, 7);
            return new SignTestStatus(data);
        }

        public void SetMode(DeviceMode mode)
        {
            byte[] result = VendorRequestIn(DeviceRequest.SetMode, (ushort)mode, 0, 1);
            if (result[0] != 1)
                throw new Exception("Set Mode unsuccessful");
        }

        public void SetLed(bool green, bool red)
        {
            VendorRequestOut(DeviceRequest.SetLed, (ushort)((green ? 1 : 0) | (red ? 2 : 0)));
        }

        public void WriteScratch(byte[] data, int startLocation = 0)
        {
            VendorRequestOut(DeviceRequest.ScratchPad, (ushort)startLocation, 0, data);
        }

        public byte[] ReadScratch(int length, int startLocation = 0)
        {
            return VendorRequestIn(DeviceRequest.ScratchPad, (ushort)startLocation, 0, (ushort)length);
        }

        public void ClearScratchFF()
        {
            VendorRequestOut(DeviceRequest.ClearScratchPad);
        }

        public byte[] FlashSpi(byte[] input)
        {
            WriteScratch(input);
            return VendorRequestIn(DeviceRequest.SpiFlash, 0, 0, (ushort)input.Length);
        }

        public byte[] FpgaSpi(byte[] input)
        {
            WriteScratch(input);
            return VendorRequestIn(DeviceRequest.SpiFpga, 0, 0, (ushort)input.Length);
        }

        void CheckAddress(int address, int alignment)
        {
            if ((address & (alignment - 1)) != 0)
                throw new Exception("Bad alignment for flash operation.");
        }
        void CheckResult(byte[] result)
        {
            if (result[0] != 1)
                throw new Exception("Flash operation unsuccessful");
        }

        public void FlashRawEraseSector(int address)
        {
            CheckAddress(address, FlashSectorSize);
            CheckResult(VendorRequestIn(DeviceRequest.FlashEraseSector, (ushort)(address / FlashSectorSize), 0, 1));
        }

        public void FlashRawEraseBlock(int address)
        {
            CheckAddress(address, FlashBlockSize);
            CheckResult(VendorRequestIn(DeviceRequest.FlashEraseBlock, (ushort)(address / FlashBlockSize), 0, 1));
        }

        public void FlashRawProgram256(int address)
        {
            CheckAddress(address, 256);
            CheckResult(VendorRequestIn(DeviceRequest.FlashProgram, (ushort)(address / 256), 0, 1));
        }

        public byte[] FlashRawRead256(int address, int length)
        {
            CheckAddress(address, 256);
            return VendorRequestIn(DeviceRequest.FlashProgram, (ushort)(address / 256), 0, (ushort)length);
        }

        public UInt32 FlashRawCrc64k(int address)
        {
            CheckAddress(address, 256);
            throw new NotImplementedException(); // Also not implemented in the microcontroller currently.
        }


        public void FlashEraseRegion(int address, int length)
        {
            int firstSector = address / FlashSectorSize;
            int lastSector = (address + length - 1) / FlashSectorSize;
            for(int i=firstSector; i<lastSector;i++)
            {
                FlashRawEraseSector(i * FlashSectorSize);
            }
        }

        public byte[] FlashRead(int address, int length)
        {
            byte[] output = new byte[length];
            int firstBlock = address / 256;
            int lastBlock = (address + length - 1) / 256;
            int writeCursor = 0;
            for (int i = firstBlock; i < lastBlock;i++)
            {
                int readAddr = i*256;
                int readBytes = 256;
                if(readAddr + readBytes > address + length)
                {
                    readBytes = address + length - (readAddr);
                }
                byte[] data = FlashRawRead256(readAddr, readBytes);

                if(readAddr < address)
                {
                    readBytes = readAddr + readBytes - address;
                    Array.Copy(data, (address - readAddr), output, writeCursor, readBytes);
                }
                else
                {
                    Array.Copy(data, 0, output, writeCursor, readBytes);
                }
                writeCursor += readBytes;
            }

            return output;
        }

        public void FlashWrite(int address, byte[] data)
        {
            byte[] buffer = new byte[256];
            int firstBlock = address / 256;
            int lastBlock = (address + data.Length - 1) / 256;
            int writeCursor = 0;
            for (int i = firstBlock; i < lastBlock; i++)
            {
                int writeAddr = i * 256;
                int writeBytes = 256;
                if (writeAddr + writeBytes > address + data.Length)
                {
                    writeBytes = address + data.Length - (writeAddr);
                }
               
                if(writeAddr < address || writeBytes != 256)
                {
                    ClearScratchFF();

                    int writeOffset = 0;
                    if (writeAddr < address)
                        writeOffset = address - writeAddr;
                    writeBytes -= writeOffset;
                    byte[] partialBuffer = new byte[writeBytes];

                    Array.Copy(data, writeCursor, partialBuffer, 0, writeBytes);
                    WriteScratch(partialBuffer, writeOffset);
                }
                else
                {
                    Array.Copy(data, writeCursor, buffer, 0, writeBytes);
                    WriteScratch(buffer);
                }

                FlashRawProgram256(writeAddr);

                writeCursor += writeBytes;
            }

        }

    }

    public class SignTestStatus
    {
        const float TolerancePercent = 0.05f; // Voltage values should be within 5%

        public SignTestStatus(byte[] rawData)
        {
            Raw = rawData;
            GeneratedTime = DateTime.Now;

            int rawVin = BitConverter.ToUInt16(rawData, 0);
            int raw3v3 = BitConverter.ToUInt16(rawData, 2);
            int raw1v2 = BitConverter.ToUInt16(rawData, 4);

            // Values are 2:14 representing the voltage's percentage of 3.3V.
            // VIN measures 1/3 of the VIN value on the test board.
            // 1V2 and 3V3 both measure 1/2 of their respective values.
            VIN = (3.3f * rawVin / 0x3FFF) * 3;
            V3v3 = (3.3f * raw3v3 / 0x3FFF) * 2;
            V1v2 = (3.3f * raw1v2 / 0x3FFF) * 2;

            Sense1 = (rawData[6] & 1) == 0;
            Sense2 = (rawData[6] & 2) == 0;
        }

        public readonly DateTime GeneratedTime;

        public readonly byte[] Raw;
        public readonly float VIN, V3v3, V1v2;
        // True = Sensed (read pin value of 0)
        public readonly bool Sense1, Sense2;

        public bool Sense
        {
            get { return Sense1 && Sense2; }
        }

        public bool DeviceGone
        {
            get { return !(Sense1 || Sense2); }
        }

        // is the soft-on phase complete?
        public bool SoftOnOk
        {
            get { return VIN > 3.0;  }
        }

        bool ToleranceOk(float expected, float actual)
        {
            float diff = actual / expected;
            if (diff < 1) diff = -diff + 2;
            diff = diff - 1;
            return diff < TolerancePercent;
        }

        // Are the power rails in tolerance?
        public bool PowerOk
        {
            get
            {
                return ToleranceOk(3.3f, V3v3) && ToleranceOk(1.2f, V1v2);
            }
        }


        public override string ToString()
        {
            return string.Format("VIN:{0:n2}V,3V3:{1:n2}V,1V2:{2:n2}V,S{3}{4}",
                VIN, V3v3, V1v2, Sense1?"t":"f", Sense2?"t":"f");
        }
    }
}
