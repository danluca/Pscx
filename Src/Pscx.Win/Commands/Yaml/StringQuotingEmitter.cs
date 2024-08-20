﻿using System;
using System.Text.RegularExpressions;
using YamlDotNet;
using YamlDotNet.Core;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.EventEmitters;

namespace Pscx.Win.Commands.Yaml {
    internal class StringQuotingEmitter : ChainedEventEmitter {
        // Patterns from https://yaml.org/spec/1.2/spec.html#id2804356
        private static Regex quotedRegex = new Regex(@"^(\~|null|true|false|on|off|yes|no|y|n|[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?|[-+]?(\.inf))?$",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);
        
        public StringQuotingEmitter(IEventEmitter next) : base(next) { }

        public override void Emit(ScalarEventInfo eventInfo, IEmitter emitter) {
            var typeCode = eventInfo.Source.Value != null ? Type.GetTypeCode(eventInfo.Source.Type) : TypeCode.Empty;

            switch (typeCode) {
                case TypeCode.Char:
                    if (Char.IsDigit((char)eventInfo.Source.Value)) {
                        eventInfo.Style = ScalarStyle.DoubleQuoted;
                    }

                    break;
                case TypeCode.String:
                    var val = eventInfo.Source.Value.ToString();
                    if (quotedRegex.IsMatch(val)) {
                        eventInfo.Style = ScalarStyle.DoubleQuoted;
                    } else if (val.IndexOf('\n') > -1) {
                        eventInfo.Style = ScalarStyle.Literal;
                    }

                    break;
            }

            base.Emit(eventInfo, emitter);
        }

        public static SerializerBuilder Add(SerializerBuilder builder) {
            return builder.WithEventEmitter(next => new StringQuotingEmitter(next));
        }
    }
}