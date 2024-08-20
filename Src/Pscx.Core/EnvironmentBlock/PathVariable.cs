using System;
using System.Collections.Generic;
using System.IO;

namespace Pscx.EnvironmentBlock {
    public sealed class PathVariable : IDisposable {
        private static readonly StringComparer Comparer = StringComparer.OrdinalIgnoreCase;

        private string _name;
        private EnvironmentVariableTarget _target;

        private List<string> _values;

        public PathVariable(string name) : this(name, EnvironmentVariableTarget.Process) {
        }

        public PathVariable(string name, EnvironmentVariableTarget target) {
            _name = name;
            _target = target;
        }

        public string Name {
            get { return _name; }
        }

        public string[] GetValues() {
            EnsureValuesLoaded();
            return _values.ToArray();
        }

        public void Append(string[] values) {
            PscxArgumentException.ThrowIfIsNull(values);
            EnsureValuesLoaded();

            foreach (var t in values) {
                Append(t);
            }
        }

        public void Append(string value) {
            PscxArgumentException.ThrowIfIsNullOrEmpty(value);
            EnsureValuesLoaded();

            value = Environment.ExpandEnvironmentVariables(value.Trim());

            if (value.Length > 0 && !Contains(value)) {
                _values.Add(value);
            }
        }

        public void Prepend(string[] values) {
            PscxArgumentException.ThrowIfIsNull(values);
            EnsureValuesLoaded();

            for (int i = values.Length - 1; i >= 0; i--) {
                Prepend(values[i]);
            }
        }

        public void Prepend(string value) {
            PscxArgumentException.ThrowIfIsNullOrEmpty(value);
            EnsureValuesLoaded();

            value = Environment.ExpandEnvironmentVariables(value.Trim());

            if (value.Length > 0 && !Contains(value)) {
                _values.Insert(0, value);
            }
        }

        public void Remove(string[] values) {
            PscxArgumentException.ThrowIfIsNull(values);
            EnsureValuesLoaded();

            foreach (var t in values) {
                Remove(t);
            }
        }

        public void Remove(string value) {
            PscxArgumentException.ThrowIfIsNullOrEmpty(value);
            EnsureValuesLoaded();

            value = Environment.ExpandEnvironmentVariables(value.Trim());
            int index = IndexOf(value);

            if (index >= 0) {
                _values.RemoveAt(index);
            }
        }

        public void Set(string[] values) {
            _values = new List<string>();
            Append(values);
        }

        public void Set(string value) {
            _values = new List<string>();
            Append(value);
        }

        public bool Contains(string value) {
            return IndexOf(value) >= 0;
        }

        public void Commit() {
            if (_values == null) {
                return;
            }

            Environment.SetEnvironmentVariable(_name, string.Join(Path.PathSeparator, _values.ToArray()), _target);
        }

        private int IndexOf(string value) {
            for (int i = 0; i < _values.Count; i++) {
                if (Comparer.Equals(_values[i], value)) {
                    return i;
                }
            }

            return -1;
        }

        private void EnsureValuesLoaded() {
            if (_values != null) {
                return;
            }

            _values = new List<string>();
            string str = Environment.GetEnvironmentVariable(_name, _target);

            if (string.IsNullOrEmpty(str)) {
                return;
            }

            ISet<string> uniqueVals = new HashSet<string>();
            string[] parts = str.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries);
            foreach (string item in parts) {
                uniqueVals.Add(item);
            }
            _values.AddRange(uniqueVals);
        }


        void IDisposable.Dispose() {
            Commit();
        }
    }
}
