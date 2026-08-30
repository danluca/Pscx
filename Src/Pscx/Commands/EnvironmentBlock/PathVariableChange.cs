using Pscx.EnvironmentBlock;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Pscx.Commands.EnvironmentBlock {
    public sealed class PathVariableChange {
        internal PathVariableChange(
            string operation,
            EnvironmentVariableTarget target,
            PathVariable variable,
            string[] before,
            string[] after,
            bool applied) {
            Operation = operation;
            Name = variable.Name;
            Target = target;
            Applied = applied;
            Before = before;
            After = after;
            Added = Distinct(after.Where(item => !Contains(before, item, variable)), variable);
            Removed = Distinct(before.Where(item => !Contains(after, item, variable)), variable);
            Retained = Distinct(after.Where(item => Contains(before, item, variable)), variable);
            Invalid = Distinct(variable.InvalidValues, variable);
            Duplicate = variable.DuplicateValues;
            Changed = !before.SequenceEqual(after, variable.Comparer);
        }

        public string Operation { get; }

        public string Name { get; }

        public EnvironmentVariableTarget Target { get; }

        public bool Applied { get; }

        public bool Changed { get; }

        public string[] Before { get; }

        public string[] After { get; }

        public string[] Added { get; }

        public string[] Removed { get; }

        public string[] Retained { get; }

        public string[] Invalid { get; }

        public string[] Duplicate { get; }

        private static bool Contains(
            IEnumerable<string> values,
            string candidate,
            PathVariable variable) {
            return values.Any(value => variable.IsEquivalent(value, candidate));
        }

        private static string[] Distinct(IEnumerable<string> values, PathVariable variable) {
            var result = new List<string>();
            foreach (string value in values) {
                if (!Contains(result, value, variable)) {
                    result.Add(value);
                }
            }
            return result.ToArray();
        }
    }
}
