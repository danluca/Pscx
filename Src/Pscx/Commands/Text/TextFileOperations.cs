using System;
using System.IO;
using System.Linq;
using System.Text;

namespace Pscx.Commands.Text
{
    public enum TextFileEncodingKind
    {
        Unknown,
        Ascii,
        Utf8,
        Utf16LittleEndian,
        Utf16BigEndian,
        Utf32LittleEndian,
        Utf32BigEndian
    }

    public enum TextFileBomKind
    {
        None,
        Utf8,
        Utf16LittleEndian,
        Utf16BigEndian,
        Utf32LittleEndian,
        Utf32BigEndian
    }

    public enum TextFileLineEndingKind
    {
        Unknown,
        None,
        Lf,
        CrLf,
        Cr,
        Mixed
    }

    public enum FinalNewlineMode
    {
        Preserve,
        Add,
        Remove
    }

    public sealed class TextFileInfo
    {
        internal TextFileInfo(
            string path,
            byte[] bytes,
            string text,
            Encoding encoding,
            int preambleLength,
            TextFileEncodingKind encodingKind,
            TextFileBomKind bom,
            bool isValidText,
            int crLfCount,
            int lfCount,
            int crCount,
            bool hasFinalNewline)
        {
            Path = path;
            Length = bytes.LongLength;
            Encoding = encodingKind;
            Bom = bom;
            IsValidText = isValidText;
            CrLfCount = crLfCount;
            LfCount = lfCount;
            CrCount = crCount;
            HasFinalNewline = hasFinalNewline;
            OriginalBytes = bytes;
            Text = text;
            DotNetEncoding = encoding;
            PreambleLength = preambleLength;

            int kinds = (crLfCount > 0 ? 1 : 0) + (lfCount > 0 ? 1 : 0) + (crCount > 0 ? 1 : 0);
            LineEnding = !isValidText
                ? TextFileLineEndingKind.Unknown
                : kinds switch
                {
                    0 => TextFileLineEndingKind.None,
                    > 1 => TextFileLineEndingKind.Mixed,
                    _ when crLfCount > 0 => TextFileLineEndingKind.CrLf,
                    _ when lfCount > 0 => TextFileLineEndingKind.Lf,
                    _ => TextFileLineEndingKind.Cr
                };
        }

        public string Path { get; }

        public long Length { get; }

        public bool IsEmpty => Length == 0;

        public TextFileEncodingKind Encoding { get; }

        public TextFileBomKind Bom { get; }

        public bool HasBom => Bom != TextFileBomKind.None;

        public bool IsValidText { get; }

        public TextFileLineEndingKind LineEnding { get; }

        public bool HasMixedLineEndings => LineEnding == TextFileLineEndingKind.Mixed;

        public int CrLfCount { get; }

        public int LfCount { get; }

        public int CrCount { get; }

        public bool HasFinalNewline { get; }

        internal byte[] OriginalBytes { get; }

        internal string Text { get; }

        internal Encoding DotNetEncoding { get; }

        internal int PreambleLength { get; }
    }

    public sealed class LineEndingCheckResult
    {
        internal LineEndingCheckResult(
            TextFileInfo current,
            string destination,
            TextFileLineEndingKind targetLineEnding,
            FinalNewlineMode finalNewline,
            bool needsConversion)
        {
            Path = current.Path;
            Destination = destination;
            TargetLineEnding = targetLineEnding;
            FinalNewline = finalNewline;
            NeedsConversion = needsConversion;
            Current = current;
        }

        public string Path { get; }

        public string Destination { get; }

        public TextFileLineEndingKind TargetLineEnding { get; }

        public FinalNewlineMode FinalNewline { get; }

        public bool NeedsConversion { get; }

        public TextFileInfo Current { get; }
    }

    internal static class TextFileOperations
    {
        private static readonly UTF8Encoding StrictUtf8NoBom = new(false, true);

        internal static TextFileInfo AnalyzeFile(string path)
        {
            return Analyze(File.ReadAllBytes(path), path);
        }

        internal static TextFileInfo Analyze(byte[] bytes, string path = null)
        {
            ArgumentNullException.ThrowIfNull(bytes);

            TextFileEncodingKind encodingKind;
            TextFileBomKind bom;
            Encoding encoding;
            int preambleLength;
            DetectEncoding(bytes, out encodingKind, out bom, out encoding, out preambleLength);

            string text = null;
            bool isValidText = true;
            try
            {
                text = encoding == null
                    ? bytes.Length == 0 ? string.Empty : null
                    : encoding.GetString(bytes, preambleLength, bytes.Length - preambleLength);
                isValidText = text != null;
            }
            catch (DecoderFallbackException)
            {
                isValidText = false;
            }

            int crLfCount = 0;
            int lfCount = 0;
            int crCount = 0;
            bool hasFinalNewline = false;
            if (isValidText)
            {
                CountLineEndings(text, out crLfCount, out lfCount, out crCount);
                hasFinalNewline = text.EndsWith('\n') || text.EndsWith('\r');
            }

            return new TextFileInfo(
                path,
                bytes,
                text,
                encoding,
                preambleLength,
                encodingKind,
                bom,
                isValidText,
                crLfCount,
                lfCount,
                crCount,
                hasFinalNewline);
        }

        internal static byte[] ConvertLineEndings(
            TextFileInfo info,
            TextFileLineEndingKind targetLineEnding,
            FinalNewlineMode finalNewline,
            Encoding explicitEncoding)
        {
            ArgumentNullException.ThrowIfNull(info);
            string text = info.Text;
            Encoding outputEncoding = explicitEncoding ?? info.DotNetEncoding;
            if (text == null && explicitEncoding != null)
            {
                text = explicitEncoding.GetString(
                    info.OriginalBytes,
                    info.PreambleLength,
                    info.OriginalBytes.Length - info.PreambleLength);
            }
            if (text == null || outputEncoding == null)
            {
                throw new InvalidDataException(
                    "The file encoding could not be determined. Specify -Encoding explicitly before converting it.");
            }

            string target = targetLineEnding switch
            {
                TextFileLineEndingKind.Lf => LineEnding.Unix,
                TextFileLineEndingKind.CrLf => LineEnding.Windows,
                _ => throw new ArgumentOutOfRangeException(nameof(targetLineEnding))
            };
            string converted = NormalizeLineEndings(text, target);
            converted = ApplyFinalNewline(converted, target, finalNewline);

            byte[] content = outputEncoding.GetBytes(converted);
            byte[] preamble = explicitEncoding == null && info.HasBom
                ? outputEncoding.GetPreamble()
                : Array.Empty<byte>();
            if (preamble.Length == 0)
            {
                return content;
            }

            byte[] result = new byte[preamble.Length + content.Length];
            Buffer.BlockCopy(preamble, 0, result, 0, preamble.Length);
            Buffer.BlockCopy(content, 0, result, preamble.Length, content.Length);
            return result;
        }

        internal static bool NeedsConversion(TextFileInfo info, byte[] convertedBytes)
        {
            return !info.OriginalBytes.SequenceEqual(convertedBytes);
        }

        private static void DetectEncoding(
            byte[] bytes,
            out TextFileEncodingKind encodingKind,
            out TextFileBomKind bom,
            out Encoding encoding,
            out int preambleLength)
        {
            if (StartsWith(bytes, 0xFF, 0xFE, 0x00, 0x00))
            {
                encodingKind = TextFileEncodingKind.Utf32LittleEndian;
                bom = TextFileBomKind.Utf32LittleEndian;
                encoding = new UTF32Encoding(false, true, true);
                preambleLength = 4;
                return;
            }
            if (StartsWith(bytes, 0x00, 0x00, 0xFE, 0xFF))
            {
                encodingKind = TextFileEncodingKind.Utf32BigEndian;
                bom = TextFileBomKind.Utf32BigEndian;
                encoding = new UTF32Encoding(true, true, true);
                preambleLength = 4;
                return;
            }
            if (StartsWith(bytes, 0xEF, 0xBB, 0xBF))
            {
                encodingKind = TextFileEncodingKind.Utf8;
                bom = TextFileBomKind.Utf8;
                encoding = new UTF8Encoding(true, true);
                preambleLength = 3;
                return;
            }
            if (StartsWith(bytes, 0xFF, 0xFE))
            {
                encodingKind = TextFileEncodingKind.Utf16LittleEndian;
                bom = TextFileBomKind.Utf16LittleEndian;
                encoding = new UnicodeEncoding(false, true, true);
                preambleLength = 2;
                return;
            }
            if (StartsWith(bytes, 0xFE, 0xFF))
            {
                encodingKind = TextFileEncodingKind.Utf16BigEndian;
                bom = TextFileBomKind.Utf16BigEndian;
                encoding = new UnicodeEncoding(true, true, true);
                preambleLength = 2;
                return;
            }

            bom = TextFileBomKind.None;
            preambleLength = 0;
            if (bytes.Length == 0)
            {
                encodingKind = TextFileEncodingKind.Unknown;
                encoding = StrictUtf8NoBom;
                return;
            }
            if (bytes.Contains((byte)0))
            {
                // NUL bytes commonly indicate BOM-less UTF-16/UTF-32 or binary
                // content. Do not misidentify those ambiguous files as ASCII or UTF-8.
                encodingKind = TextFileEncodingKind.Unknown;
                encoding = null;
                return;
            }
            if (bytes.All(value => value <= 0x7F))
            {
                encodingKind = TextFileEncodingKind.Ascii;
                encoding = Encoding.ASCII;
                return;
            }
            try
            {
                StrictUtf8NoBom.GetString(bytes);
                encodingKind = TextFileEncodingKind.Utf8;
                encoding = StrictUtf8NoBom;
            }
            catch (DecoderFallbackException)
            {
                encodingKind = TextFileEncodingKind.Unknown;
                encoding = null;
            }
        }

        private static bool StartsWith(byte[] bytes, params byte[] prefix)
        {
            return bytes.Length >= prefix.Length && !prefix.Where((value, index) => bytes[index] != value).Any();
        }

        private static void CountLineEndings(string text, out int crLfCount, out int lfCount, out int crCount)
        {
            crLfCount = 0;
            lfCount = 0;
            crCount = 0;
            for (int index = 0; index < text.Length; index++)
            {
                if (text[index] == '\r')
                {
                    if (index + 1 < text.Length && text[index + 1] == '\n')
                    {
                        crLfCount++;
                        index++;
                    }
                    else
                    {
                        crCount++;
                    }
                }
                else if (text[index] == '\n')
                {
                    lfCount++;
                }
            }
        }

        private static string NormalizeLineEndings(string text, string target)
        {
            var builder = new StringBuilder(text.Length);
            for (int index = 0; index < text.Length; index++)
            {
                if (text[index] == '\r')
                {
                    if (index + 1 < text.Length && text[index + 1] == '\n')
                    {
                        index++;
                    }
                    builder.Append(target);
                }
                else if (text[index] == '\n')
                {
                    builder.Append(target);
                }
                else
                {
                    builder.Append(text[index]);
                }
            }
            return builder.ToString();
        }

        private static string ApplyFinalNewline(string text, string target, FinalNewlineMode mode)
        {
            bool hasFinalNewline = text.EndsWith('\n') || text.EndsWith('\r');
            if (mode == FinalNewlineMode.Add && !hasFinalNewline)
            {
                return text + target;
            }
            if (mode == FinalNewlineMode.Remove && hasFinalNewline)
            {
                return text.TrimEnd('\r', '\n');
            }
            return text;
        }
    }
}
