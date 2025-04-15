[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/4nHL7_6-)
[![Open in Visual Studio Code](https://classroom.github.com/assets/open-in-vscode-2e0aaae1b6195c2367325f4f02e2d04e9abb55f0b24a779b69b11b9e10269abc.svg)](https://classroom.github.com/online_ide?assignment_repo_id=18895668&assignment_repo_type=AssignmentRepo)
# CS 164: Programming Assignment 1

[PA1 Specification]: https://drive.google.com/open?id=1oYcJ5iv7Wt8oZNS1bEfswAklbMxDtwqB
[ChocoPy Specification]: https://drive.google.com/file/d/1mrgrUFHMdcqhBYzXHG24VcIiSrymR6wt

Note: Users running Windows should replace the colon (`:`) with a semicolon (`;`) in the classpath argument for all command listed below.

## Getting started

Run the following command to generate and compile your parser, and then run all the provided tests:

    mvn clean package

    java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --test --dir src/test/data/pa1/sample/

In the starter code, only one test should pass. Your objective is to build a parser that passes all the provided tests and meets the assignment specifications.

To manually observe the output of your parser when run on a given input ChocoPy program, run the following command (replace the last argument to change the input file):

    java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s src/test/data/pa1/sample/expr_plus.py

You can check the output produced by the staff-provided reference implementation on the same input file, as follows:

    java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=r src/test/data/pa1/sample/expr_plus.py

Try this with another input file as well, such as `src/test/data/pa1/sample/coverage.py`, to see what happens when the results disagree.

## Assignment specifications

See the [PA1 specification][] on the course
website for a detailed specification of the assignment.

Refer to the [ChocoPy Specification][] on the CS164 web site
for the specification of the ChocoPy language. 

## Receiving updates to this repository

Add the `upstream` repository remotes (you only need to do this once in your local clone):

    git remote add upstream https://github.com/cs164berkeley/pa1-chocopy-parser.git

To sync with updates upstream:

    git pull upstream master


## Submission writeup

Team member 1: 

Isadora Pacheco Ribeiro
Horas: 15-20 horas. 

# Explicações

Primeiro sobre o JFlex:

a principal dificuldade foi a parte da Indentação. 
Para isso, eu criei 2 estados (inicialmente era apenas o estado de String, ai depois eu aprendi a utilizar e usei para a indentação).

- STRING_STATE - Para ficar modularizado o local para reconhecer strings.
- INDENT_STATE - Para reconhecer a indentação.

Também outro diferencial foi a customização da função do scanner de next_tokens, 
Eu usei a diretiva de %function para criar uma função customizada para o scanner.

## Sistema de Indentação

O sistema de indentação foi implementado com as seguintes características principais:

1. **Variáveis de Estado da Indentação**:
```java
private boolean needToProcessIndentation = false;
private String pendingIndentation = "";
private char pendingChar = '\0';
```
- `needToProcessIndentation`: Flag que indica se precisamos processar a indentação
- `pendingIndentation`: Armazena os caracteres de espaço em branco que precisam ser processados
- `pendingChar`: Armazena um caractere pendente se necessário

2. **Classe IndentationState**:
```java
private class IndentationState {
    private final Stack<Integer> indentStack = new Stack<>();
    private boolean isLogicalLineStart = true;
    private boolean isFirstLine = true;
    private boolean lastLineBlankOrComment = true;
    private boolean expectBlockIndent = false;
    // ... getters e setters
}
```
Esta classe gerencia o estado da indentação:
- `indentStack`: Mantém o controle dos níveis de indentação
- `isLogicalLineStart`: Indica se estamos no início de uma linha lógica
- `isFirstLine`: Indica se estamos na primeira linha
- `lastLineBlankOrComment`: Controla se a última linha estava em branco ou era um comentário
- `expectBlockIndent`: Indica se estamos esperando uma indentação de bloco (após dois pontos)

3. **Método calculateIndent**:
```java
private int calculateIndent(String whitespace) {
    int count = 0;
    for (char c : whitespace.toCharArray()) {
        if (c == ' ') {
            count++;
        } else if (c == '\t') {
            count = (count / 8 + 1) * 8;
        }
    }
    return count;
}
```
Este método calcula o nível de indentação:
- Conta espaços normalmente
- Para tabulações, arredonda para o próximo múltiplo de 8
- Retorna o nível total de indentação

4. **Métodos de Manipulação de Indentação**:
```java
private void handleIncreaseIndent(int currentIndent) {
    indentState.getIndentStack().push(currentIndent);
    pendingTokens.add(symbol(ChocoPyTokens.INDENT));
}

private void handleDecreaseIndent(int currentIndent) {
    Stack<Integer> stack = indentState.getIndentStack();
    boolean validIndent = stack.contains(currentIndent);
    if (!validIndent) {
        pendingTokens.add(symbol(ChocoPyTokens.UNRECOGNIZED, "IndentationError"));
        return;
    }
    while (stack.size() > 1 && currentIndent < stack.peek()) {
        int popped = stack.pop();
        pendingTokens.add(symbol(ChocoPyTokens.DEDENT));
    }
}
```
Estes métodos tratam:
- `handleIncreaseIndent`: Adiciona novo nível de indentação e gera token INDENT
- `handleDecreaseIndent`: Remove níveis de indentação e gera tokens DEDENT até encontrar o nível correspondente
- `handleBlankOrCommentLine`: Ignora linhas em branco ou comentários
- `handleEOF`: Gera tokens DEDENT até que a pilha tenha apenas um nível

5. **Processamento Principal de Indentação**:
```java
private void handleIndentation(String leadingWhitespace) {
    if (!indentState.isLogicalLineStart()) return;
    
    int currentIndent = calculateIndent(leadingWhitespace);
    int previousIndent = indentState.getIndentStack().peek();
    
    if (currentIndent > previousIndent) {
        // Trata aumento
        if (indentState.isExpectingBlockIndent()) {
            handleIncreaseIndent(currentIndent);
        } else {
            pendingTokens.add(symbol(ChocoPyTokens.UNRECOGNIZED, "IndentationError"));
        }
    } else if (currentIndent < previousIndent) {
        // Trata diminuição
        handleDecreaseIndent(currentIndent);
    }
    // ... trata caso de mesma indentação
}
```
Este é o método principal que:
- Calcula a indentação atual
- Compara com a indentação anterior
- Trata aumentos, diminuições ou mesmo nível
- Gera tokens apropriados (INDENT/DEDENT)

6. **Estado INDENT_STATE**:
```java
<INDENT_STATE> {
    {IndentChar}+ {
        String whitespace = yytext();
        handleIndentation(whitespace);
        if (!pendingTokens.isEmpty()) {
            return pendingTokens.removeFirst();
        }
        yybegin(YYINITIAL);
    }
    // ... outras regras
}
```
Este é o estado JFlex que processa a indentação:
- Corresponde aos caracteres de indentação no início da linha
- Processa a indentação
- Retorna quaisquer tokens gerados
- Transiciona de volta para o estado inicial

O sistema de indentação segue as regras do Chocopy:
- Espaços e tabulações são permitidos
- Tabulações são tratadas como múltiplos de 8 espaços
- A indentação deve ser consistente dentro de um bloco
- Erros de indentação são relatados quando:
  - A indentação aumenta sem um dois pontos
  - A indentação diminui para um nível inválido
  - É usada indentação inconsistente


## Substituição do método next_token() padrão com a diretiva %function

A diretiva %function é uma diretiva do JFlex que permite definir uma função customizada para o scanner.

Ela substitui o método next_token() padrão do JFlex, que é o método que é chamado para obter o próximo token.


A estratégia é. 

1. TOkens pendentes - verificamos se há INDENT, DEDENT, NEWLINE, ou EOF
se tiver, retorna o primeiro token pendente.
2. INdentação pendente - se needToProcessIndentation é true, chama o método handleIndentation para calcular a indentação atual e gerar os tokens apropriados.
3. se nem 1 nem 2, chama o método next_token() padrão do JFlex. - que agora é a função customizada originalNextTokens()


## Macros de REgex

Todos os macros de regex estão no arquivo ChocoPy.jflex e já estão explicados no próprio comentário do código.


## YYINITIAL E os outros estados que foram criados

O JFlex permite a criação de diferentes estados para processar diferentes partes do código. No nosso lexer, criamos três estados principais:

1. **YYINITIAL (Estado Inicial)**:
```jflex
<YYINITIAL> {
    // Regras para processar tokens básicos
    {LineBreak} {
        indentState.setLogicalLineStart(true);
        yybegin(INDENT_STATE);
        return symbol(ChocoPyTokens.NEWLINE, "\n");
    }
    
    \" { 
        yybegin(STRING_STATE); 
        string_buffer.setLength(0);
    }
    
    // ... outras regras para keywords, operadores, etc.
}
```
Este é o estado padrão do lexer que:
- Processa a maioria dos tokens básicos
- Gerencia transições para outros estados
- Trata keywords, operadores, identificadores, etc.
- Cmomentários são processados com handleBlankOrCommentLine para que a indentação seja feita corretamente
- Transiciona para INDENT_STATE quando encontra quebra de linha (\n or \r)
- Transiciona para STRING_STATE quando encontra aspas duplas

2. **STRING_STATE (Estado de String)**:
```jflex
<STRING_STATE> {
    \" {
        yybegin(YYINITIAL);
        String content = string_buffer.toString();
        // ... processa o conteúdo da string
    }
    
    \\\" { string_buffer.append('"'); }
    \\\\ { string_buffer.append('\\'); }
    \\n  { string_buffer.append('\n'); }
    \\t  { string_buffer.append('\t'); }
    
    {ValidStringChar}+ { string_buffer.append(yytext()); }
}
```
Este estado é responsável por:
- Acumular caracteres de string em string_buffer até encontrar outra aspas duplas
- Reconhecer sequências de escape validas como \\n \\t \\\ \\\\
- reportar erros lexicos em caso 
    - escape invalido
    - quebra de linha nao escapada
    - eof sem fechar a string 
- Retornar ao YYINITIAL quando a string termina
- Gerar tokens STRING ou IDSTRING dependendo do conteúdo
    - IDSTRING é strings que passam no regex de ID

3. **INDENT_STATE (Estado de Indentação)**:
```java
<INDENT_STATE> {
    {IndentChar}+ {
        String whitespace = yytext();
        handleIndentation(whitespace);
        if (!pendingTokens.isEmpty()) {
            return pendingTokens.removeFirst();
        }
        yybegin(YYINITIAL);
    }
    
    "#" [^\r\n]* {LineBreak} {
        handleBlankOrCommentLine();
        yybegin(INDENT_STATE); 
    }
    
    {LineBreak} {
        handleBlankOrCommentLine();
    }
    
    {NonIndentStart} {
        // ... processa início de linha sem indentação
        yybegin(YYINITIAL); 
    }
}
```
Ativa assim que encontra uma quebra de linha (\n or \r)
O scanner:
- Lê o whitespace inicial da linha e processa a indentação com o handleIndentation
- trata comentários e linhas brancas
- se detectar que a linha tem conteúdo, mas sem indentação empilha tokens dedent e manda de volta o primeiro caractere da linha para ser reprocessado no estado de YYINITIAL



A transição entre estados é feita usando o comando `yybegin()`, que muda o estado atual do lexer. Cada estado tem suas próprias regras de correspondência e ações, permitindo um processamento mais organizado e modular do código fonte.

# Arquivo CUP - Gramática



Uma das solicitações eram que o parse oferecesse a mensagem de erro
Parse error near token <TOKEN> : lexema

Isso foi feito com uma sobrecarga do método syntax_error() gerando as mensagens padronizadas

Uma coisa: o primeiro teste está errado
e para passar nele, tive que adicionar isso aqui:

if (token != null && token.toUpperCase().contains("ASSIGN")) {
    token = "EQ";
}

Porque? Bem, no teste, ele espera que o erro seja 

Parse error near token EQ : =

Mas EQ não é o caractere =, esse é o ASSIGN. Logo, o teste está errado, pois o EQ é o caractere de igualdade que tem dois iguais ==.

## Classes e Métodos Utilitários para Construção da AST

 classes e métodos auxiliares que ajudam na construção da AST (Abstract Syntax Tree).

Garantia que para cada nó da AST, contenha as localizações [linha_inicial, coluna_inicial, linha_final, coluna_final]
que passe nos testes. 


1. **Classe FuncBody**:
```java
class FuncBody {
    public final List<Declaration> declarations;
    public final List<Stmt> statements;
    private final ComplexSymbolFactory.Location endLocation;
    // ...
}
```
Esta classe auxilia na construção do corpo de funções:
- Armazena declarações e statements
- Calcula a localização final baseada no conteúdo
- Usada para construir blocos de função com informações de localização precisas

2. **Classe Block**:
```java
class Block {
    private final List<Stmt> statements;
    private final ComplexSymbolFactory.Location startLocation;
    private final ComplexSymbolFactory.Location endLocation;
    // ...
}
```
Gerencia blocos de código:
- Armazena statements dentro do bloco
- Mantém informações de localização inicial e final
- Fornece métodos para acessar localizações e statements
- Usado para blocos de if, while, for, etc.

3. **Classe ElifItem**:
```java
class ElifItem {
    public final Expr condition;
    public final List<Stmt> body;
    private final ComplexSymbolFactory.Location conditionLeft;
    private final ComplexSymbolFactory.Location conditionRight;
    // ...
}
```
Auxilia na construção de estruturas if-elif-else:
- Armazena condição e corpo de cada elif
- Mantém informações de localização para cada parte
- Usado para construir a estrutura aninhada corretamente

4. **Classe LocationManager**:
```java
class LocationManager {
    private static final boolean DEBUG_LOCATIONS = true;
    // ...
}
```

A classe locationManager é responsável por gerenciar as localizações de cada nó da AST.
- Extrair a localização mais a direita de lista de statements ou declarations
- Ajustar colunas finais (ex:  +1 ) para cobrir corretamente os blocos
- Calcular a última localização válida entre duas 
- Depurar localizações com DEBUG_LOCATIONS - Foi desativado pq só era usado para debug



5. **Métodos de Manipulação de Localização**:
```java
private ComplexSymbolFactory.Location getDeepestLocation(Node node, boolean isEnd)
private ComplexSymbolFactory.Location getDeepestEndLocation(List<? extends Node> nodes)
private ComplexSymbolFactory.Location getDeepestListEndLocation(List<? extends Node> nodes)
private ComplexSymbolFactory.Location getLatestLocation(ComplexSymbolFactory.Location loc1, ComplexSymbolFactory.Location loc2)
```
Estes métodos auxiliam na:
- Cálculo de localizações mais profundas em nós
- Determinação de localizações finais em listas
- Comparação e seleção de localizações mais recentes
- Ajuste de localizações para construção precisa da AST

6. **Métodos de Processamento de Blocos**:
```java
private List<Stmt> handlePassBlock(List<Stmt> statements)
private List<Stmt> buildNestedIfs(List<ElifItem> elifs, List<Stmt> finalElseBodyList, ComplexSymbolFactory.Location finalBlockLocation)
private List<Stmt> processFinalElse(Block elseBlockOpt)
```
Estes métodos tratam:
- Processamento de blocos pass
- Construção de estruturas if-elif-else aninhadas
- Processamento de blocos else
- Gerenciamento de localizações em blocos

7. **Métodos de Ajuste de Localização**:
```java
private void updateLastDedentLocation(ComplexSymbolFactory.Location loc)
private ComplexSymbolFactory.Location adjustEndLocation(ComplexSymbolFactory.Location loc)
```
Estes métodos:
- Atualizam localizações de dedentação
- Ajustam localizações finais para construção precisa da AST
- Mantêm o controle de níveis de indentação

Estas classes e métodos são essenciais para:
- Construção precisa da AST com informações de localização
- Gerenciamento de blocos e estruturas de controle
- Tratamento de indentação e dedentação
- Debug e desenvolvimento do parser

## Método buildNestedIfs

O método `buildNestedIfs` é responsável por construir a estrutura aninhada de if-elif-else. Aqui está sua implementação:

```java
private List<Stmt> buildNestedIfs(List<ElifItem> elifs, List<Stmt> finalElseBodyList, 
                                ComplexSymbolFactory.Location finalBlockLocation) {
    List<Stmt> currentNestedElseBodyList = finalElseBodyList;
    
    for (int i = elifs.size() - 1; i >= 0; i--) {
        ElifItem item = elifs.get(i);
        
        ComplexSymbolFactory.Location startLoc = item.getConditionLeft();
        ComplexSymbolFactory.Location endLoc = finalBlockLocation;
        
        System.out.println("[DEBUG] ELIF " + i + " location: [" + 
            startLoc.getLine() + ":" + startLoc.getColumn() + "] to [" + 
            endLoc.getLine() + ":" + endLoc.getColumn() + "]");
        
        List<Stmt> processedBody = handlePassBlock(item.body);
        
        currentNestedElseBodyList = Collections.singletonList(
            new IfStmt(startLoc, endLoc, 
                    item.condition,
                    processedBody,
                    currentNestedElseBodyList)
        );
    }
    return currentNestedElseBodyList;
}
```

Este método é crucial para a construção correta da AST de estruturas if-elif-else porque:

1. **Construção Inversa**:
   - Processa os elifs de trás para frente (do último para o primeiro)
   - Isso permite construir a estrutura aninhada corretamente, onde cada elif se torna o else do if anterior

2. **Gerenciamento de Localizações**:
   - Usa `getConditionLeft()` para obter a localização inicial de cada elif
   - Usa `finalBlockLocation` para a localização final
   - Mantém informações precisas de linha/coluna para cada nó

3. **Processamento de Corpos**:
   - Usa `handlePassBlock` para processar o corpo de cada elif
   - Trata corretamente blocos pass vazios
   - Mantém a estrutura de statements intacta

4. **Construção da AST**:
   - Cria novos nós `IfStmt` para cada elif
   - Aninha corretamente os blocos else
   - Mantém a estrutura semântica da linguagem

5. **Exemplo de Uso**:
```python
if x > 0:
    print("positive")
elif x < 0:
    print("negative")
else:
    print("zero")
```
É transformado em:
```java
IfStmt(
    condition: x > 0,
    thenBody: [print("positive")],
    elseBody: [
        IfStmt(
            condition: x < 0,
            thenBody: [print("negative")],
            elseBody: [print("zero")]
        )
    ]
)
```



## Funções auxiliares em Action code 
Extração de localização:

getLeftLoc(List<Node>), 
getRightLoc(List<Node>), 
nodeLeftLoc(Node), 
nodeRightLoc(Node)

Todas elas fazem checagem de null e loc.length


### Terminais 

Os terminais estão definidos em 


## Declarações de Terminais e Não-Terminais

### Terminais
Os terminais são os tokens retornados pelo lexer. Existem dois tipos de declaração:
- `terminal <identificador1>, <identificador2>, ...;` - Declara identificadores como símbolos terminais distintos
- `terminal <tipo> <identificador1>, ...;` - Declara identificadores com valores semânticos do tipo `<tipo>`

#### Principais Terminais
```java
// Controle de fluxo e indentação
terminal NEWLINE, INDENT, DEDENT;

// Identificadores e literais
terminal String ID, IDSTRING, STRING;
terminal BigInteger NUMBER;

// Palavras-chave
terminal CLASS, DEF, IF, ELIF, ELSE, WHILE, FOR, RETURN;

// Operadores
terminal PLUS, MINUS, TIMES, EQ, NE, LT, GT;
terminal LPAREN, RPAREN, COLON, COMMA, ASSIGN;
```

### Não-Terminais
Os não-terminais são definidos nas regras de produção. Eles podem ser declarados com valores semânticos:
- `non terminal <tipo> <identificador1>, ..., <identificadorn>;` - Define símbolos não-terminais com valores semânticos do tipo `<tipo>`

#### Principais Não-Terminais
```java
// Estrutura do programa
non terminal Program program;
non terminal List<Declaration> def_list;
non terminal List<Stmt> stmt_list;

// Declarações
non terminal Declaration def, var_def, func_def;
non terminal TypedVar typed_var;
non terminal TypeAnnotation type;

// Expressões
non terminal Expr expr, logical_expr, arith_expr;
non terminal List<Expr> expr_list;
```

### Precedência de Operadores
Regras de precedência (da menor para a maior):
```java
precedence left OR, AND;
precedence nonassoc EQ, NE, LT, GT;
precedence left PLUS, MINUS;
precedence left TIMES;
precedence right ASSIGN;
```

## Gramática ChocoPy

###  Estrutura Básica do Programa

Um programa em ChocoPy é organizado em duas partes principais:
- **Declarações no Topo**: Variáveis, funções e classes que definem a estrutura do programa
- **Comandos Globais**: Instruções executáveis no nível mais alto do programa

###  Declarações

O ChocoPy suporta três tipos principais de declarações:

1. **Declaração de Variáveis** (`var_def`)
   - Permite definir variáveis com tipo e valor inicial
   - Exemplo: `x: int = 10`

2. **Definição de Funções** (`func_def`)
   - Suporta parâmetros tipados
   - Tipo de retorno opcional
   - Corpo da função com declarações e comandos
   - Exemplo: `def soma(a: int, b: int) -> int: return a + b`

3. **Definição de Classes** (`class_def`)
   - Atributos e métodos
   - Exemplo: `class Pessoa(object): nome: str = ""`

###  Blocos e Estruturação

A linguagem usa indentação para estruturar o código:
- Blocos são delimitados por `INDENT` e `DEDENT` - como foi visto e explicado na parte do Lexer.
- Estruturas de controle (`if`, `while`, `for`) usam blocos indentados

###  Expressões

O ChocoPy oferece uma rica variedade de expressões:

1. **Expressões Booleanas**
   - Operadores lógicos: `and`, `or`, `not`
   - Exemplo: `if x > 0 and y < 10:`

2. **Comparações**
   - Operadores: `==`, `!=`, `<`, `>`, `<=`, `>=`, `is`
   - Exemplo: `if x == y or x is None:`

3. **Aritmética**
   - Operadores básicos: `+`, `-`, `*`, `//`, `%`
   - Exemplo: `resultado = (x + y) * 2`

4. **Acesso a Objetos**
   - Chamadas de função: `soma(1, 2)`
   - Acesso a membros: `pessoa.nome`
   - Chamadas de método: `lista.append(10)`
   - Índices: `lista[0]`

###  Açúcar Sintático

Para tornar a linguagem mais amigável, algumas construções são transformadas em estruturas mais básicas:
- `elif` e `else` são convertidos em `if` aninhados
- `pass` e `return None` são tratados como expressões com valor nulo

###  Sistema de Tipos

O ChocoPy oferece:
- Tipos primitivos: `int`, `bool`, `str`
- Tipos de lista: `[int]`, `[str]`, etc.
- Tipos de retorno opcionais em funções (padrão: `<None>`)

