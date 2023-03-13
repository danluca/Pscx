using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Management.Automation;
using System.Text;

namespace Pscx.TypeAccelerators
{
    #region To-HexString
    public struct Hex
    {
        private readonly string _value;

        public Hex(Int32 value) {
            _value = String.Format("0x{0:x8}", value);
        }

        public Hex(uint value) {
            _value = String.Format("0x{0:x8}", value);
        }

        public Hex(short value) {
            _value = String.Format("0x{0:x4}", value);
        }

        public Hex(byte value) {
            _value = String.Format("0x{0:x2}", value);
        }

        public Hex(char value) {
            _value = charToHex(value);
        }

        public Hex(long value) {
            _value = String.Format("0x{0:x16}", value);
        }

        public Hex(ulong value) {
            _value = String.Format("0x{0:x16}", value);
        }

        public Hex(byte[] value) {
            _value = Convert.ToHexString(value);
        }

        public Hex(short[] value) {
            StringBuilder sb = new(value.Length * 2);
            foreach (short b in value) {
                sb.AppendFormat("{0:x4}", b);
            }

            _value = sb.ToString();
        }

        public Hex(int[] value) {
            StringBuilder sb = new(value.Length * 2);
            foreach (int b in value) {
                sb.AppendFormat("{0:x8}", b);
            }

            _value = sb.ToString();
        }

        public Hex(long[] value) {
            StringBuilder sb = new(value.Length * 2);
            foreach (long b in value) {
                sb.AppendFormat("{0:x16}", b);
            }

            _value = sb.ToString();
        }

        public Hex(char[] value) {
            StringBuilder sb = new(value.Length * 2);
            foreach (char b in value) {
                sb.Append(charToHex(b));
            }

            _value = sb.ToString();
        }

        public Hex(PSObject value) {
            _value = objectToHex(value);
        }

        public Hex(object[] value) {
            StringBuilder sb = new(value.Length * 2);
            foreach (var o in value) {
                sb.Append(objectToHex(o));
            }

            _value = sb.ToString();
        }

        public Hex(string value) : this(value.ToCharArray()) { }

        public override string ToString() {
            return _value;
        }

        public static byte[] BytesFromHex(string sHex) {
            if (sHex.Length % 2 != 0)
                throw new ArgumentException("The hex string cannot have an odd number of digits for extracting bytes");
            int arrSize = sHex.Length >> 1; //div by 2
            byte[] arr = new byte[arrSize];
            for (int i = 0; i < arrSize; i+=2) {
                arr[i] = (byte)((hexCharToInt(sHex[i]) << 4) + (hexCharToInt(sHex[i + 1])));
            }
            return arr;
        }

        public static short[] ShortsFromHex(string sHex) {
            if (sHex.Length % 4 != 0)
                throw new ArgumentException("The hex string must have a mod(4) aligned number of digits for extracting shorts");
            int arrSize = sHex.Length >> 2; //div by 4
            short[] arr = new short[arrSize];
            for (int i = 0; i < arrSize; i+=4) {
                byte[] oneShort = BytesFromHex(sHex.Substring(i, 4));
                //BigEndian conversion
                arr[i] = (short)(oneShort[0] << 8 + oneShort[1]);
            }
            return arr;
        }

        public static int[] IntsFromHex(string sHex) {
            if (sHex.Length % 8 != 0)
                throw new ArgumentException("The hex string must have a mod(8) aligned number of digits for extracting ints");
            int arrSize = sHex.Length >> 3; //div by 8
            int[] arr = new int[arrSize];
            for (int i = 0; i < arrSize; i+=8) {
                byte[] oneInt = BytesFromHex(sHex.Substring(i, 8));
                //BigEndian conversion
                arr[i] = (int)(oneInt[0] << 24 + oneInt[1] << 16 + oneInt[2] << 8 + oneInt[3]);
            }
            return arr;
        }

        public static long[] LongsFromHex(string sHex) {
            if (sHex.Length % 16 != 0)
                throw new ArgumentException("The hex string must have a mod(16) aligned number of digits for extracting longs");
            int arrSize = sHex.Length >> 4; //div by 16
            long[] arr = new long[arrSize];
            for (int i = 0; i < arrSize; i+=16) {
                byte[] oneLong = BytesFromHex(sHex.Substring(i, 16));
                //BigEndian conversion
                arr[i] = (long)(oneLong[0] << 56 + oneLong[1] << 48 + oneLong[2] << 40 + oneLong[3] << 32 + oneLong[4] << 24 + oneLong[5] << 16 + oneLong[6] << 8 + oneLong[7]);
            }
            return arr;
        }

        /// <summary>
        /// Convert given hex string into corresponding string value, accounting for up to 2-byte long UTF-8 characters
        /// </summary>
        /// <param name="sHex"></param>
        /// <returns></returns>
        public static string StringFromHex(string sHex) {
            byte[] strBytes = BytesFromHex(sHex);
            bool validString = true;
            for (int i = 0; i < strBytes.Length; i += 2) {
                if (i + 1 < strBytes.Length) {
                    // is the byte pair a UTF-8 2 byte character? or two single UTF-8 characters?
                    short shChar = (short)(strBytes[i] << 8 + strBytes[i + 1]);
                    validString = validString && (char.IsLetterOrDigit((char)strBytes[i]) || char.IsLetterOrDigit((char)strBytes[i + 1]) || char.IsLetterOrDigit((char)shChar));
                } else {
                    validString = validString && char.IsLetterOrDigit((char)strBytes[i]);
                }
            }

            if (validString) {
                return Encoding.UTF8.GetString(strBytes);
            }

            throw new ArgumentException($"'{sHex}' string contains non-character codes - most likely this is binary data, should convert to byte[]");
        }

        #region Internal Utilities
        private static string charToHex(char c) {
            int ic = Convert.ToUInt16(c);
            if (ic > byte.MaxValue) {
                return $"{ic:x4}";
            } else {
                return $"{ic:x2}";
            }
        }

        private static string objectToHex(object o) {
            StringBuilder sb = new();
            object obj = o is PSObject po ? po.BaseObject : o;
            switch (obj) {
                case string s:
                    foreach (char c in s) {
                        sb.Append(charToHex(c));
                    }
                    break;
                case char c:
                    sb.Append(charToHex(c));
                    break;
                case byte:
                case sbyte:
                    sb.AppendFormat("{0:x2}", o);
                    break;
                case short:
                case ushort:
                    sb.AppendFormat("{0:x4}", o);
                    break;
                case int:
                case uint:
                    sb.AppendFormat("{0:x8}", o);
                    break;
                case long:
                case ulong:
                    sb.AppendFormat("{0:x16}", o);
                    break;
                case null:
                    break;
                default:
                    foreach (char c in o?.ToString() ?? string.Empty) {
                        sb.Append(charToHex(c));
                    }
                    break;

            }

            return sb.ToString();
        }
        /// <summary>
        /// Convenience to convert a single hex character into the numeric value it represents.
        /// The validity of incoming hex character is asserted - i.e. '0' through '9', 'a' through 'f' or 'A' through 'F'
        /// </summary>
        /// <param name="hex"></param>
        /// <returns>integer value of the hex character provided</returns>
        /// <exception cref="ArgumentException">when incoming character is not in valid hex range [0-9a-f]</exception>
        private static int hexCharToInt(char hex) {
            const string validHexChars = "0123456789ABCDEF";
            char upHex = char.ToUpper(hex);
            bool valid = validHexChars.Contains(upHex);
            if (!valid)
                throw new ArgumentException($"{hex} is an invalid hex character - only [0-9a-f] are allowed (case insensitive)");

            int val = upHex;
            //For uppercase A-F letters: return val - (val < 58 ? 48 : 55);
            return val - (val < 58 ? 48 : 55);
    }
        #endregion
    }
    #endregion
}
