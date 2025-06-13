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
            
            if (string.IsNullOrEmpty(value)) {
                return; // nothing to append
            }
            // if value is already in the list, nothing to do
            if (Contains(value)) {
                return;
            }

            _values.Add(value);
        }

        public void Prepend(string[] values) {
            PscxArgumentException.ThrowIfIsNull(values);
            EnsureValuesLoaded();

            for (int i = values.Length - 1; i >= 0; i--) {
                Prepend(values[i]);
            }
        }
        
        /// <summary>
        /// Prepends a specified value to the beginning of the environment variable's path.
        /// </summary>
        /// <param name="value">
        /// The value to prepend to the path. If the value is already present in the path, 
        /// it will be moved to the beginning. If the value is empty or null, no action is taken.
        /// </param>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="value"/> is <c>null</c> or an empty string.
        /// </exception>
        public void Prepend(string value) {
            PscxArgumentException.ThrowIfIsNullOrEmpty(value);
            EnsureValuesLoaded();

            value = Environment.ExpandEnvironmentVariables(value.Trim());
            
            if (string.IsNullOrEmpty(value)) {
                return; // nothing to prepend
            }

            // Check if the value is already at the start to avoid unnecessary operations
            if (_values.Count > 0 && Comparer.Equals(_values[0], value)) {
                return;
            }
            // if value is already in the list, we remove it first such that we can add it to the front
            if (Contains(value)) {
                Remove(value);
            }

            _values.Insert(0, value);
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
