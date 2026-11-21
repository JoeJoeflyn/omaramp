"""What the panel runs for every backend command: cliamp_ctl.py from its cached bytecode.

Python never caches the bytecode of the script it is started with, so running cliamp_ctl.py
directly compiled all of it again on every call, a third of a status poll. Run as a module it
loads from __pycache__ like any import.
"""
import runpy

runpy.run_module("cliamp_ctl", run_name="__main__")
