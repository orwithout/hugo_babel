# -*- coding: utf-8 -*-
"""
生成 UDC Summary 目录树 · 前缀法
用法:
  pip install rdflib==7.0.0
  python make_udc_tree_by_prefix.py udc.rdf ./UDC
"""

import os, re, sys
import rdflib
from pathlib import Path
from rdflib.namespace import SKOS

PAT_NUM = re.compile(r'^\d+(?:\.\d+)*$')   # 纯数字 + 点

def safe(txt):  # 文件系统安全名
    return re.sub(r'[\\/:"*?<>|]', '_', txt)

def load_numeric_concepts(file_path):
    g = rdflib.Graph()
    g.parse(file_path, format="turtle")     # 官方发布其实是 Turtle
    concepts = {}
    for s, _, lit in g.triples((None, SKOS.notation, None)):
        code = str(lit)
        if PAT_NUM.match(code):
            # 英文 prefLabel → 退回任意 → 再退回代码
            labels = list(g.objects(s, SKOS.prefLabel))
            if labels:
                en = next((l for l in labels if l.language == 'en'), None)
                lbl = str(en or labels[0])
            else:
                lbl = code
            concepts[code] = lbl
    return concepts

def ensure_parent(code, codes):
    """递归寻找最近存在的父级代码；若无则返回首位数字"""
    if '.' in code:
        parent = code.rsplit('.', 1)[0]
    elif len(code) > 1:
        parent = code[:-1]
    else:
        return None
    return parent if parent in codes else ensure_parent(parent, codes)

def build_tree(codes):
    tree = {}
    for c in codes:
        p = ensure_parent(c, codes)
        tree.setdefault(p, []).append(c)
    return tree

def make_dirs(root, code, label, tree, labels):
    """递归写目录；code 为 None 时代表虚根"""
    if code is not None:
        name = f"{safe(code)}_{safe(label.split(',')[0].split(';')[0]).strip()}"
        root = root / name
        root.mkdir(exist_ok=True)
        (root / "_label.txt").write_text(label, "utf-8")
    for child in sorted(tree.get(code, []), key=lambda x: [len(x), x]):
        make_dirs(root, child, labels[child], tree, labels)

def main(rdf_file, out_dir):
    labels = load_numeric_concepts(rdf_file)
    tree   = build_tree(labels.keys())
    outp   = Path(out_dir); outp.mkdir(parents=True, exist_ok=True)
    make_dirs(outp, None, "", tree, labels)
    print(f"✅ 目录完成：{len(labels)} 个概念写入 {outp.resolve()}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: python make_udc_tree_by_prefix.py <udc.rdf> <输出目录>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
