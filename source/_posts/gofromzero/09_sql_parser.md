---
title: 【从零单排Golang】第九话：用go语言解析并分析sql语句的方法
date: 2023/03/04 00:21:17
categories:
- 从零单排Golang
tags:
- Golang
- SQL
- vitess-sqlparser
- tidbparser
- DDL
---

在`Golang`的实战中，总会遇到一些场景，比如抓包分析`sql`指纹，或者是输入`sql`时检查`sql`的风险，这类操作都需要解析`sql`的工具才能够生效。今天，就来介绍一些`Golang`当中解析`sql`的工具包和使用方法。

本文介绍的工具是[vitess-sqlparser](https://github.com/blastrain/vitess-sqlparser)，主要结合了两个`sql`解析工具：

- [xwb1989/sqlparser](https://github.com/xwb1989/sqlparser)
- [tidbparser](https://github.com/pingcap/tidb/tree/master/parser)

其中，`xwb1989/sqlparser`项目支持的功能有限，尤其对于`DDL`没有很好的支持，而`tidbparser`则功能比较全面。下面以`tidbparser`为例，讲述一下解析以及分析`sql`里`DDL`语句的一种方式。

代码相关写法可以查看[这篇文章](https://zhuanlan.zhihu.com/p/34770765)。首先，我们先自定义一个要验证的`DDL`语句：

<!-- more -->

```sql
ALTER TABLE Persons DROP COLUMN DateOfBirth, DROP COLUMN ID;
```

很明显是一个删除列的语句，这类语句在线上执行也是会有风险的。如果用`xwb1989/sqlparser`工具，是无法解析识别的，而用`tidbparser`，可以这样写：


```go
package sqlcheck

import (
    "fmt"
    "github.com/blastrain/vitess-sqlparser/tidbparser/ast"
    "github.com/blastrain/vitess-sqlparser/tidbparser/parser"
    "testing"
)

// 定义一个可以访问SQL解析树节点的Visitor
type DropColumnVisitor struct {
    TableName string
    Columns   []string
}

func (v *DropColumnVisitor) IsValid() bool {
    return v.TableName != "" && len(v.Columns) > 0
}

func (v *DropColumnVisitor) Enter(in ast.Node) (out ast.Node, skipChildren bool) {
    fmt.Printf("%T\n", in)
    // 识别了ALTER就直接访问子节点，看是不是DropColumn
    switch in.(type) {
    case *ast.AlterTableStmt:
        if v.TableName != "" {
            break
        }
        node := in.(*ast.AlterTableStmt)
        v.TableName = node.Table.Name.String()
        for _, spec := range node.Specs {
            // 看解析的Tp枚举是不是ast.AlterTableDropColumn对应的枚举
            if spec.Tp == ast.AlterTableDropColumn {
                v.Columns = append(v.Columns, spec.OldColumnName.OrigColName())
            }
        }
    default:
        break
    }
    // 不需要访问子节点
    return in, true
}

func (v *DropColumnVisitor) Leave(in ast.Node) (out ast.Node, ok bool) {
    return in, true
}

func TestParseDropColumn(t *testing.T) {
    sql := "ALTER TABLE Persons DROP COLUMN DateOfBirth, DROP COLUMN ID;"
    sqlParser := parser.New()
    stmtNodes, err := sqlParser.Parse(sql, "", "")
    if err != nil {
        t.Fatalf("Parse error: %v", err)
    }
    t.Logf("stmt: %s", JsonDump(stmtNodes))

    v := &DropColumnVisitor{
        TableName: "",
        Columns:   []string{},
    }
    // 每个根节点开始起访问
    for _, stmtNode := range stmtNodes {
        stmtNode.Accept(v)
    }
    t.Logf("visitor: %s", JsonDump(v))

    if !v.IsValid() {
        t.Fatalf("invalid drop column ddl")
    }
    t.Logf("drop columns %v at table %s", v.Columns, v.TableName)
}
```

当解析了`sql`之后，我们需要定义一个实现了`Enter`和`Leave`方法的`Visitor`接口`interface`，才能够开始识别`sql`解析树具体的内容。这里灵活用到了接口`interface`的设计方式，在[cache-interface](https://utmhikari.top/2023/02/18/gofromzero/08_cache_interface/)一篇文章中也有介绍到。如果解析的节点是`*ast.AlterTableStmt`类型，那么首先它就是个`ALTER`语句，再往下需要查`Specs`属性里是不是有`DROP COLUMN`对应的类型枚举，如果有的话，那就是一个删除列的语句了。

我们打印整个解析树，就能够清晰的看到结果：

```text
=== RUN   TestParseDropColumn
    vitess_sqlparser_test.go:50: stmt: [
          {
            "Table": {
              "Schema": {
                "O": "",
                "L": ""
              },
              "Name": {
                "O": "Persons",
                "L": "persons"
              },
              "DBInfo": null,
              "TableInfo": null,
              "IndexHints": null
            },
            "Specs": [
              {
                "Tp": 4,
                "Name": "",
                "Constraint": null,
                "Options": null,
                "NewTable": null,
                "NewColumns": null,
                "OldColumnName": {
                  "Schema": {
                    "O": "",
                    "L": ""
                  },
                  "Table": {
                    "O": "",
                    "L": ""
                  },
                  "Name": {
                    "O": "DateOfBirth",
                    "L": "dateofbirth"
                  }
                },
                "Position": null,
                "LockType": 0
              },
              {
                "Tp": 4,
                "Name": "",
                "Constraint": null,
                "Options": null,
                "NewTable": null,
                "NewColumns": null,
                "OldColumnName": {
                  "Schema": {
                    "O": "",
                    "L": ""
                  },
                  "Table": {
                    "O": "",
                    "L": ""
                  },
                  "Name": {
                    "O": "ID",
                    "L": "id"
                  }
                },
                "Position": null,
                "LockType": 0
              }
            ]
          }
        ]

    vitess_sqlparser_test.go:59: visitor: {
          "TableName": "Persons",
          "Columns": [
            "DateOfBirth",
            "ID"
          ]
        }
    vitess_sqlparser_test.go:64: drop columns [DateOfBirth ID] at table Persons
--- PASS: TestParseDropColumn (0.00s)
PASS
```

通过解析之后，就能够提取出来`ALTER`的表`Persons`以及`DROP`的列`DateOfBirth`跟`ID`，也就确定了这是一个删除列的操作。

可以看到，`sql`解析器本身是非常强大灵活的。通过我们自定义一些逻辑规则，能很方便的检查`sql`的合法性跟风险性。
