// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using Microsoft.PowerShell;
using NUnit.Framework;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;

namespace PscxUnitTests {
    [Serializable]
    public class PipelineErrorsException : Exception {
        public PipelineErrorsException() { }
        public PipelineErrorsException(string message) : base(message) { }
        public PipelineErrorsException(string message, Exception inner) : base(message, inner) { }

        internal PipelineErrorsException(IList errors)
            : base("Pipeline invocation has returned errors.") {
            List = errors;
        }

        public IList List { get; }

        public override string Message {
            get {
                StringBuilder msg = new();
                foreach (object err in List) {
                    if (err != null) {
                        msg.AppendLine(err.ToString());
                        msg.AppendLine();
                    }
                }

                return msg.ToString();
            }
        }
    }

    public class PscxCmdletTest {
        private PowerShell _runspaceInvoke;

        public Runspace Runspace { get; private set; }

        public string Configuration {
            get {
#if DEBUG
                return "Debug\\net8.0";
#else
                return "Release\\net8.0";
#endif
            }
        }

        public string ProjectDir {
            get {
                string testDllPath = GetType().Assembly.Location;
                if (testDllPath.StartsWith("file:///", StringComparison.OrdinalIgnoreCase)) {
                    testDllPath = testDllPath.Remove(0, 8);
                }

                string projectDir = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(testDllPath), @"..\..\.."));
                return projectDir;
            }
        }

        public string SolutionDir {
            get {
                string testDllPath = GetType().Assembly.Location;
                if (testDllPath.StartsWith("file:///", StringComparison.OrdinalIgnoreCase)) {
                    testDllPath = testDllPath.Remove(0, 8);
                }

                string solutionDir = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(testDllPath), @"..\..\..\.."));
                return solutionDir;
            }
        }

        public Collection<PSObject> Invoke(string script, params object[] input) {
            _runspaceInvoke.AddScript(script);
            Collection<PSObject> output = _runspaceInvoke.Invoke(input);
            IList errors = _runspaceInvoke.Streams.Error;

            if (errors != null && errors.Count > 0) {
                throw new PipelineErrorsException(errors);
            }

            return output;
        }

        public Collection<PSObject> Invoke(params Command[] commands) {
            using (Pipeline pipe = Runspace.CreatePipeline()) {
                foreach (Command cmd in commands) {
                    pipe.Commands.Add(cmd);
                }

                pipe.Input.Close();
                Collection<PSObject> output = pipe.Invoke();

                if (!pipe.Error.EndOfPipeline) {
                    throw new PipelineErrorsException(pipe.Error.ReadToEnd());
                }

                return output;
            }
        }

        public PSObject InvokeReturnOne(string script, params object[] input) {
            return SelectFirst(Invoke(script, input));
        }

        public PSObject InvokeReturnOne(params Command[] commands) {
            return SelectFirst(Invoke(commands));
        }

        public T InvokeReturnOne<T>(string script, params object[] input) {
            return GetBaseObject<T>(InvokeReturnOne(script, input));
        }

        public T InvokeReturnOne<T>(params Command[] commands) {
            return GetBaseObject<T>(InvokeReturnOne(commands));
        }

        public T GetBaseObject<T>(PSObject obj) {
            if (obj != null) {
                return (T)obj.BaseObject;
            }

            return default;
        }

        public T SelectFirst<T>(IList<T> objects) {
            if (objects.Count > 0) {
                return objects[0];
            }

            return default;
        }

        protected void AssertDoesNotContain(object expected, IList collection) {
            Assert.That(collection.Contains(expected), Is.False);
        }

        [OneTimeSetUpAttribute]
        public virtual void SetUp() {
            string pathToModule = Path.Combine(ProjectDir, @"bin\" + Configuration + @"\Pscx.psd1");
            var initialSession = InitialSessionState.CreateDefault();
            initialSession.ExecutionPolicy = ExecutionPolicy.RemoteSigned;
            initialSession.ImportPSModule(pathToModule);
            Runspace = RunspaceFactory.CreateRunspace(initialSession);
            Runspace.Open();
            _runspaceInvoke = PowerShell.Create(Runspace);
        }

        [OneTimeTearDown]
        public virtual void TearDown() {
            Runspace.Close();
        }
    }
}