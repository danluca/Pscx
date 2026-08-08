// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;

namespace Pscx.Reflection {
    [Serializable]
    public class InvalidPEFileException : Exception {
        public InvalidPEFileException() { }
        public InvalidPEFileException(string message) : base(message) { }
        public InvalidPEFileException(string message, Exception inner) : base(message, inner) { }

        internal static void ThrowInvalidDosHeader() {
            throw new InvalidPEFileException("Invalid MS-DOS header");
        }

        internal static void ThrowInvalidCoffHeader() {
            throw new InvalidPEFileException("Invalid COFF header");
        }

        internal static void ThrowInvalidPEHeader() {
            throw new InvalidPEFileException("Invalid PE header");
        }

        internal static void ThrowInvalidCorHeader() {
            throw new InvalidPEFileException("Invalid CLR header");
        }

        internal static void ThrowInvalidRva() {
            throw new InvalidPEFileException("Invalid relative virtual address");
        }
    }
}