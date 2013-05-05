#!/usr/bin/env python

import json
import re
import sys

TOKEN_CSS_CLASSES = { "Comment": "c",
                      "Error": "err",
                      "Keyword": "k",
                      "Operator": "o",
                      "Comment.Multiline": "cm",
                      "Comment.Preproc": "cp",
                      "Comment.Single": "c1",
                      "Comment.Special": "cs",
                      "Generic.Deleted": "gd",
                      "Generic.Emph": "ge",
                      "Generic.Error": "gr",
                      "Generic.Heading": "gh",
                      "Generic.Inserted": "gi",
                      "Generic.Output": "go",
                      "Generic.Prompt": "gp",
                      "Generic.Strong": "gs",
                      "Generic.Subheading": "gu",
                      "Generic.Traceback": "gt",
                      "Keyword.Constant": "kc",
                      "Keyword.Declaration": "kd",
                      "Keyword.Namespace": "kn",
                      "Keyword.Pseudo": "kp",
                      "Keyword.Reserved": "kr",
                      "Keyword.Type": "kt",
                      "Literal.Number": "m",
                      "Literal.String": "s",
                      "Name.Attribute": "na",
                      "Name.Builtin": "nb",
                      "Name.Class": "nc",
                      "Name.Constant": "no",
                      "Name.Decorator": "nd",
                      "Name.Entity": "ni",
                      "Name.Exception": "ne",
                      "Name.Function": "nf",
                      "Name.Label": "nl",
                      "Name.Namespace": "nn",
                      "Name.Tag": "nt",
                      "Name.Variable": "nv",
                      "Operator.Word": "ow",
                      "Text.Whitespace": "w",
                      "Literal.Number.Float": "mf",
                      "Literal.Number.Hex": "mh",
                      "Literal.Number.Integer": "mi",
                      "Literal.Number.Oct": "mo",
                      "Literal.String.Backtick": "sb",
                      "Literal.String.Char": "sc",
                      "Literal.String.Doc": "sd",
                      "Literal.String.Double": "s2",
                      "Literal.String.Escape": "se",
                      "Literal.String.Heredoc": "sh",
                      "Literal.String.Interpol": "si",
                      "Literal.String.Other": "sx",
                      "Literal.String.Regex": "sr",
                      "Literal.String.Single": "s1",
                      "Literal.String.Symbol": "ss",
                      "Name.Builtin.Pseudo": "bp",
                      "Name.Variable.Class": "vc",
                      "Name.Variable.Global": "vg",
                      "Name.Variable.Instance": "vi",
                      "Literal.Number.Integer.Long": "il", }

def lines2tokens(lines):
    for line in lines:
        token_type, text = line.split("\t", 1)
        text = eval(text, {"__builtins__": None}, {})
        if token_type.startswith('Token.'):
            token_type = token_type[6:]
        _head = True
        for piece in text.split("\n"):
            if not _head:
                yield ["\n", 'Text.Newline']
            if piece <> "":
                if piece.isspace():
                    yield [piece, 'Text.Whitespace']
                else:
                    yield [piece, token_type, TOKEN_CSS_CLASSES.get(token_type, None)]
            _head = False

json.dump(tuple(lines2tokens(sys.stdin)), sys.stdout)
