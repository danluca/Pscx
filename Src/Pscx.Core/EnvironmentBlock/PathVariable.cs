using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace Pscx.EnvironmentBlock {
    public sealed class PathVariable : IDisposable {
        private readonly string _name;
        private readonly EnvironmentVariableTarget _target;
        private readonly bool _normalize;
        private readonly bool _validate;
        private readonly bool _retainUnavailable;
        private readonly bool _stripQuotes;
        private readonly List<string> _invalidValues = new();
        private readonly List<string> _duplicateValues = new();
        private List<string> _originalValues;
        private List<string> _values;

        public PathVariable(string name) : this(name, EnvironmentVariableTarget.Process) {
        }

        public PathVariable(string name, EnvironmentVariableTarget target) :
            this(name, target, false, false, false, false, false) {
        }

        public PathVariable(
            string name,
            EnvironmentVariableTarget target,
            bool caseInsensitive,
            bool normalize,
            bool validate,
            bool retainUnavailable,
            bool stripQuotes = false) {
            _name = name;
            _target = target;
            _normalize = normalize;
            _validate = validate || retainUnavailable;
            _retainUnavailable = retainUnavailable;
            _stripQuotes = stripQuotes || normalize;
            Comparer = OperatingSystem.IsWindows() || caseInsensitive ?
                StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal;
        }

        public StringComparer Comparer { get; }

        public string Name => _name;

        public string[] DuplicateValues {
            get {
                EnsureValuesLoaded();
                return _duplicateValues.ToArray();
            }
        }

        public string[] InvalidValues {
            get {
                EnsureValuesLoaded();
                return _invalidValues.ToArray();
            }
        }

        public string[] GetOriginalValues() {
            EnsureValuesLoaded();
            return _originalValues.ToArray();
        }

        public string[] GetValues() {
            EnsureValuesLoaded();
            return _values.ToArray();
        }

        public void Append(string[] values) {
            PscxArgumentException.ThrowIfIsNull(values);
            EnsureValuesLoaded();

            foreach (string value in values) {
                Append(value);
            }
        }

        public void Append(string value) {
            PscxArgumentException.ThrowIfIsNullOrEmpty(value);
            EnsureValuesLoaded();

            if (!TryPrepareValue(value, out string preparedValue)) {
                return;
            }
            if (Contains(preparedValue)) {
                _duplicateValues.Add(preparedValue);
                return;
            }

            _values.Add(preparedValue);
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

            if (!TryPrepareValue(value, out string preparedValue)) {
                return;
            }

            int index = IndexOf(preparedValue);
            if (index == 0) {
                _duplicateValues.Add(preparedValue);
                return;
            }
            if (index > 0) {
                _duplicateValues.Add(preparedValue);
                _values.RemoveAt(index);
            }

            _values.Insert(0, preparedValue);
        }

        public void Remove(string[] values) {
            PscxArgumentException.ThrowIfIsNull(values);
            EnsureValuesLoaded();

            foreach (string value in values) {
                Remove(value);
            }
        }

        public void Remove(string value) {
            PscxArgumentException.ThrowIfIsNullOrEmpty(value);
            EnsureValuesLoaded();

            if (!TryPrepareValue(value, out string preparedValue, retainForRemoval: true)) {
                return;
            }
            int index = IndexOf(preparedValue);
            if (index >= 0) {
                _values.RemoveAt(index);
            }
        }

        public void Set(string[] values) {
            PscxArgumentException.ThrowIfIsNull(values);
            EnsureValuesLoaded();
            _values.Clear();
            Append(values);
        }

        public void Set(string value) {
            PscxArgumentException.ThrowIfIsNullOrEmpty(value);
            Set(new[] { value });
        }

        public bool Contains(string value) {
            return IndexOf(value) >= 0;
        }

        public bool IsEquivalent(string left, string right) {
            return Comparer.Equals(left, right);
        }

        public void Commit() {
            if (_values == null) {
                return;
            }

            Environment.SetEnvironmentVariable(
                _name,
                string.Join(Path.PathSeparator, _values),
                _target);
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

            string value = Environment.GetEnvironmentVariable(_name, _target);
            _originalValues = string.IsNullOrEmpty(value) ?
                new List<string>() :
                value.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries).ToList();
            _values = new List<string>();
            foreach (string item in _originalValues) {
                if (!TryPrepareValue(item, out string preparedValue)) {
                    continue;
                }
                if (Contains(preparedValue)) {
                    _duplicateValues.Add(preparedValue);
                    continue;
                }
                _values.Add(preparedValue);
            }
        }

        private bool TryPrepareValue(
            string value,
            out string preparedValue,
            bool retainForRemoval = false) {
            preparedValue = Environment.ExpandEnvironmentVariables(value.Trim());
            if (_stripQuotes) {
                preparedValue = preparedValue.Trim('"', '\'');
            }
            if (string.IsNullOrWhiteSpace(preparedValue)) {
                return false;
            }

            try {
                if (_normalize) {
                    preparedValue = Path.TrimEndingDirectorySeparator(Path.GetFullPath(preparedValue));
                }
            }
            catch (Exception ex) when (
                ex is ArgumentException ||
                ex is IOException ||
                ex is NotSupportedException) {
                _invalidValues.Add(preparedValue);
                return _retainUnavailable || retainForRemoval;
            }

            if (_validate && !File.Exists(preparedValue) && !Directory.Exists(preparedValue)) {
                _invalidValues.Add(preparedValue);
                return _retainUnavailable || retainForRemoval;
            }

            return true;
        }

        void IDisposable.Dispose() {
            Commit();
        }
    }
}
