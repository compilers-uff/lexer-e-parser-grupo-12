package chocopy.pa1;
import java_cup.runtime.*;
import java.math.BigInteger; 
import java.util.regex.Pattern;
import java.util.Stack;
import java.util.LinkedList;
import java.util.regex.Matcher;

%%

/*** Do not change the flags below unless you know what you are doing. ***/

%unicode
%line
%column
%class ChocoPyLexer
%public
%cupsym ChocoPyTokens
%cup

/*
Vou utilizar a abordagem de Scanner Functtion Customization - Explicada no README.md
Adicionando essa diretiva para que o JFlex possa usar a função originalNextToken
ao invés de next_token()
*/
%function originalNextToken 
%cupdebug

%state STRING_STATE
%state INDENT_STATE
%eofclose false

/*** Do not change the flags above unless you know what you are doing. ***/

/* The following code section is copied verbatim to the
 * generated lexer class. */
%{
    /* The code below includes some convenience methods to create tokens
     * of a given type and optionally a value that the CUP parser can
     * understand. Specifically, a lot of the logic below deals with
     * embedded information about where in the source code a given token
     * was recognized, so that the parser can report errors accurately.
     * (It need not be modified for this project.) */

    // Buffer para acumular caracteres de strings
    private StringBuilder string_buffer = new StringBuilder();

    // Armazenamento da linha e coluna onde começou a string para reportar a localização correta na AST
    private int string_start_line;
    private int string_start_col;

    // Regex para identificar IDs
    private static final Pattern ID_REGEX_PATTERN = Pattern.compile("[a-zA-Z_][a-zA-Z0-9_]*");

    /** Producer of token-related values for the parser. */
    final ComplexSymbolFactory symbolFactory = new ComplexSymbolFactory();

    /** Return a terminal symbol of syntactic category TYPE and no
     *  semantic value at the current source location. */
    private Symbol symbol(int type) {
        return symbol(type, yytext());
    }

    /** Return a terminal symbol of syntactic category TYPE and semantic
     *  value VALUE at the current source location. */
    private Symbol symbol(int type, Object value) {
        log("Criando token: " + ChocoPyTokens.terminalNames[type] + " valor: '" + value + "' na linha " + (yyline + 1) + " coluna " + (yycolumn + 1));
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[type], type,
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1),
            new ComplexSymbolFactory.Location(yyline + 1,yycolumn + yylength()),
            value);
    }

    private static final boolean DEBUG = false;

    private void log(String message) {
        if (DEBUG) {
            System.out.println("[DEBUG] " + message);
        }
    }

    // Calcula a quantidade total de espaços correspondentes ao whitespace inicial de uma linha, tabulações precisa ser múltiplos de 8
    private int calculateIndent(String whitespace) {
        int count = 0;

        for (char c : whitespace.toCharArray()) {
            if (c == ' ') {
                count++;
            } else if (c == '\t') {
                count = (count / 8 + 1) * 8;
            }
        }
        log("Calculado indentação: '" + whitespace.replace("\t", "\\t") + "' = " + count + " espaços");
        return count;
    }

    private boolean needToProcessIndentation = false;
    private String pendingIndentation = "";
    private char pendingChar = '\0';

    /* Indentação */

    /* 
    
    Utiliza-se uma pilha que rastreia o nível de indentação esperados,
    Gerando token INDENT quando a indentação aumenta e DEDENT quando ela diminiu
    Deterctamos e reportar erro qnd a indentação quando o aumento ocorre fora de contextos válidos
    Ignora mudançás de linhas de comentários ou linha em branco
    e usamos flags para ajudar no controle. 

    O método principal é o handleIndentation, que é chamado ao encontrar

    se aumentou -> verifica se era esperado de um bloco indentado, se sim, gera Indent
    se diminiu -> gera dedent até que o nível de indentação seja o esperado
    se mesmo -> mantém o nivel atual

    O método handleIncreaseIndent adiciona o nível de indentação à pilha e gera INDENT
    handleDecreaseIndent remove o nível de indentação da pilha até que o nível esperado seja encontrado
    handleBlankOrCommentLine é chamado para lidar com linhas em branco ou comentários
    handleEOF é chamado quando o fim do arquivo é detectado, gerando DEDENTs até que a pilha tenha apenas um nível

    */

     private class IndentationState {
        private final Stack<Integer> indentStack = new Stack<>();
        private boolean isLogicalLineStart = true;
        private boolean isFirstLine = true;
        private boolean lastLineBlankOrComment = true;
        private boolean expectBlockIndent = false;



        public IndentationState() {
            indentStack.push(0); 
        }
        public boolean isExpectingBlockIndent() { return expectBlockIndent; }
        public void setExpectingBlockIndent(boolean value) { expectBlockIndent = value; }
        public Stack<Integer> getIndentStack() { return indentStack; }
        public boolean isLogicalLineStart() { return isLogicalLineStart; }
        public void setLogicalLineStart(boolean value) { isLogicalLineStart = value; }
        public boolean isFirstLine() { return isFirstLine; }
        public void setFirstLine(boolean value) { isFirstLine = value; }
        public boolean isLastLineBlankOrComment() { return lastLineBlankOrComment; }
        public void setLastLineBlankOrComment(boolean value) { lastLineBlankOrComment = value; }
        
    }

    private final IndentationState indentState = new IndentationState();
    private final LinkedList<Symbol> pendingTokens = new LinkedList<>();

    private void handleIncreaseIndent(int currentIndent) {
        log("handleIncreaseIndent: adicionando indentação " + currentIndent + " à pilha"); 
        indentState.getIndentStack().push(currentIndent);
        log("handleIncreaseIndent: adicionando token INDENT à fila");
        pendingTokens.add(symbol(ChocoPyTokens.INDENT));
    }

    private void handleDecreaseIndent(int currentIndent) {
        Stack<Integer> stack = indentState.getIndentStack();
        log("handleDecreaseIndent: verificando indentação " + currentIndent + ", pilha atual: " + stack);
        boolean validIndent = stack.contains(currentIndent);

        if (!validIndent) {
            log("Aviso: Indentação " + currentIndent + " não encontrada na pilha: " + stack);            
            pendingTokens.add(symbol(ChocoPyTokens.UNRECOGNIZED, "IndentationError"));
            return;
        }
        
        while (stack.size() > 1 && currentIndent < stack.peek()) {
            int popped = stack.pop();
            log("handleDecreaseIndent: removendo indentação " + popped + ", adicionando DEDENT");
            pendingTokens.add(symbol(ChocoPyTokens.DEDENT));
        }
    }

    private void handleIndentation(String leadingWhitespace) {
        log("handleIndentation: leadingWhitespace = '" + leadingWhitespace + "'");
        if (!indentState.isLogicalLineStart()) {
            log("handleIndentation: Não é início de linha lógica, ignoramos indentação");
            return; 
        }
        
        indentState.setLogicalLineStart(false);
        boolean wasLastLineBlankOrComment = indentState.isLastLineBlankOrComment();
        
        log("indentState.isLogicalLineStart() = " + indentState.isLogicalLineStart());
        log("indentState.isFirstLine() = " + indentState.isFirstLine());
        log("indentState.isLastLineBlankOrComment() = " + indentState.isLastLineBlankOrComment());
        log("indentState.isExpectingBlockIndent() = " + indentState.isExpectingBlockIndent());
        log("indentState.getIndentStack() = " + indentState.getIndentStack());

        int currentIndent = calculateIndent(leadingWhitespace);
        int previousIndent = indentState.getIndentStack().peek();
        
        if (currentIndent > previousIndent) {
            // CASO 1: Aumentou a indentação (INDENT)
            if (indentState.isExpectingBlockIndent()) {
                log("Aumentando indentação para " + currentIndent + " (stack: " + indentState.getIndentStack() + ")");
                handleIncreaseIndent(currentIndent);
                indentState.setExpectingBlockIndent(false); 
            } else {
                log("IndentationError: indentação inesperada fora de bloco");
                pendingTokens.add(symbol(ChocoPyTokens.UNRECOGNIZED, "IndentationError"));
            }
        } else if (currentIndent < previousIndent) {
            // CASO 2: Diminuiu a indentação (DEDENT)
            log("Diminuindo indentação para " + currentIndent + " (stack: " + indentState.getIndentStack() + ")");
            handleDecreaseIndent(currentIndent);
            indentState.setExpectingBlockIndent(false); 
        } else {
            // CASO 3: Mesma indentação
            log("Mantendo indentação para " + currentIndent + " (stack: " + indentState.getIndentStack() + ")");
            boolean isEmptyLeading = leadingWhitespace.isEmpty();
            log("Chamando handleSameIndent com fromEmptyLeadingWhitespace=" + isEmptyLeading + ", wasLastLineBlankOrComment=" + wasLastLineBlankOrComment);
            handleSameIndent(isEmptyLeading, wasLastLineBlankOrComment); 
            indentState.setExpectingBlockIndent(false); 
        }
            
        indentState.setFirstLine(false);
        indentState.setLastLineBlankOrComment(false);
        log("handleIndentation: indentState.isFirstLine() = " + indentState.isFirstLine() + ", indentState.isLastLineBlankOrComment() = " + indentState.isLastLineBlankOrComment());
    }


    private void handleSameIndent(boolean fromEmptyLeadingWhitespace, boolean wasLastLineBlankOrComment) {
        log("handleSameIndent: fromEmptyLeadingWhitespace=" + fromEmptyLeadingWhitespace +
            ", isFirstLine()=" + indentState.isFirstLine() +
            ", wasLastLineBlankOrComment=" + wasLastLineBlankOrComment);

        log("Não adicionando NEWLINE extra para linha com mesma indentação.");
    }


    private void handleBlankOrCommentLine() {
        log("handleBlankOrCommentLine: indentState.isFirstLine() = " + indentState.isFirstLine() + ", indentState.isLastLineBlankOrComment() = " + indentState.isLastLineBlankOrComment());
        indentState.setLogicalLineStart(true);
        indentState.setLastLineBlankOrComment(true);
    }

    private boolean eofProcessed = false;
    /**
    * Prepara para o fim do arquivo, emitindo NEWLINE final e DEDENTs.
    */
    private void handleEOF() {

        if (eofProcessed) {
            log("handleEOF: EOF já processado, ignorando");
            return;
        }
    
        eofProcessed = true;

        Stack<Integer> stack = indentState.getIndentStack();
        while (stack.size() > 1) {
            stack.pop();
            log("handleEOF: Adicionando DEDENT");
            pendingTokens.add(symbol(ChocoPyTokens.DEDENT));
        }
        
        pendingTokens.add(symbol(ChocoPyTokens.EOF));
    }
    
    private static int recursionDepth = 0;
    private static final int MAX_RECURSION = 100;

    public Symbol next_token() throws java.io.IOException {
        log("next_token: recursionDepth = " + recursionDepth);
        if (recursionDepth > MAX_RECURSION) {
            recursionDepth = 0; // Reseta para a próxima vez
            log("ERRO: Recursão excessiva detectada, retornando EOF de emergência");
            return symbol(ChocoPyTokens.EOF);
        }
        
        try {
            recursionDepth++;
            
            // 1. Retorna tokens pendentes primeiro
            if (!pendingTokens.isEmpty()) {
                return pendingTokens.removeFirst();
            }
            
            // 2. Processa indentação APENAS se estamos no início de uma linha lógica
            if (needToProcessIndentation) {
                needToProcessIndentation = false; 
                
                if (indentState.isLogicalLineStart()) { 
                    log("next_token: processando indentação pendente: '" + pendingIndentation + "'");
                    handleIndentation(pendingIndentation);
                    if (!pendingTokens.isEmpty()) {
                        Symbol token = pendingTokens.removeFirst();
                        log("Retornando token de indentação pendente: " + token);
                        return token;
                    }
                } else {
                    log("next_token: ignorando processamento de indentação (não estamos no início de uma linha lógica)");
                }
            }
            
            log("next_token: chamando originalNextToken()");
            Symbol token = originalNextToken();
            log("next_token: token = " + token);
            return token;
            
        } finally {
            recursionDepth--;
        }
    }

    
%}

/* Macros (regexes used in rules below) */

WhiteSpace = [ \t\f\r] 
/* tudo que pode ser um espaço em branco */
IndentChar = [ \t]
/* tudo que pode ser um caractere de indentação (espaço ou tab) */
NonIndentStart = [^ \t\f\r\n#]
/* tudo que pode ser um caractere não indentador */
LineBreak = \r\n | \n | \r
/* tudo que pode ser uma quebra de linha */
Digit = [0-9]
/* tudo que pode ser um dígito */
NonZeroDigit = [1-9]
/* tudo que pode ser um dígito não nulo */
ALPHABET = [a-zA-Z_]
/* tudo que pode ser uma letra ou underline */
ALNUM = [a-zA-Z0-9_]
/* tudo que pode ser uma letra, dígito ou underline */
NonWhiteSpaceNonComment = [^\r\n\t \f#]
/* tudo que pode ser um caractere não branco, não quebra de linha, não tab, não espaço em branco e não comentário */

/* Derivados do de cima */

IntegerLiteral = 0 | {NonZeroDigit}{Digit}*

/* Identifiers: derivados do de cima */

ID = {ALPHABET}{ALNUM}*  // Identificador convecional sem aspas para nomes de variaveis funcoes e outras coisas

/* "ID" entre aspas: Ex: "Point", "Foo123" etc. 
   O conteúdo interno segue as mesmas regras de ID, mas
   fica entre aspas duplas.
   isso é para lembrar para o IDSTRING. vai ser tratado no STRING_STATE
*/
ValidStringChar = [^\n\r\"\\]
/* tudo que pode ser um caractere válido dentro de uma string, exceto quebra de linha, aspas duplas e barra invertida */


%%
 

                          

<YYINITIAL> {
	
    /* 
        uma linha que contém apenas espaços em branco (ou nenhum), 
        seguida por uma quebra de linha, e essa linha tem que começar desde o início (^).
    
     */
    ^{WhiteSpace}*{LineBreak} {
        log("Regra de linha em branco acionada com quebra de linha: " + 
        yytext().replace("\n", "\\n").replace("\r", "\\r"));
        handleBlankOrCommentLine();
    }
    
    /*
        quebra de linha -> muda para INDENT_STATE
     */
    {LineBreak} {
        log("Quebra de linha detectada, mudando para INDENT_STATE");
        indentState.setLogicalLineStart(true);
        yybegin(INDENT_STATE);
        return symbol(ChocoPyTokens.NEWLINE, "\n");
    }

    /*
        string -> muda para STRING_STATE
     */
    \" { 
        log("[DEBUG] Iniciando string na linha " + (yyline + 1) + " coluna " + (yycolumn + 1));
        string_start_line = yyline;
        string_start_col = yycolumn;
        yybegin(STRING_STATE); 
        string_buffer.setLength(0);
    }
    /* Keyword, lembre que a ordem das regras importa, 
    entao se voce colocar as regras de keyword antes de ID, 
    elas serao confundidas com identificadores e nao serao reconhecidas. */

    "False"    { log("[DEBUG] Reconhecido keyword: False"); return symbol(ChocoPyTokens.FALSE); }
    "None"     { log("[DEBUG] Reconhecido keyword: None"); return symbol(ChocoPyTokens.NONE); }
    "True"     { log("[DEBUG] Reconhecido keyword: True"); return symbol(ChocoPyTokens.TRUE); }
    "and"      { log("[DEBUG] Reconhecido keyword: and"); return symbol(ChocoPyTokens.AND); }
    "class"    { log("[DEBUG] Reconhecido keyword: class"); return symbol(ChocoPyTokens.CLASS); }
    "def"      { log("[DEBUG] Reconhecido keyword: def"); return symbol(ChocoPyTokens.DEF); }
    "elif"     { log("[DEBUG] Reconhecido keyword: elif"); return symbol(ChocoPyTokens.ELIF); }
    "else"     { log("[DEBUG] Reconhecido keyword: else"); return symbol(ChocoPyTokens.ELSE); }
    "for"      { log("[DEBUG] Reconhecido keyword: for"); return symbol(ChocoPyTokens.FOR); }
    "global"   { log("[DEBUG] Reconhecido keyword: global"); return symbol(ChocoPyTokens.GLOBAL); }
    "if"       { log("[DEBUG] Reconhecido keyword: if"); return symbol(ChocoPyTokens.IF); }
    "in"       { log("[DEBUG] Reconhecido keyword: in"); return symbol(ChocoPyTokens.IN); }
    "is"       { log("[DEBUG] Reconhecido keyword: is"); return symbol(ChocoPyTokens.IS); }
    "nonlocal" { log("[DEBUG] Reconhecido keyword: nonlocal"); return symbol(ChocoPyTokens.NONLOCAL); }
    "not"      { log("[DEBUG] Reconhecido keyword: not"); return symbol(ChocoPyTokens.NOT); }
    "or"       { log("[DEBUG] Reconhecido keyword: or"); return symbol(ChocoPyTokens.OR); }
    "pass"     { log("[DEBUG] Reconhecido keyword: pass"); return symbol(ChocoPyTokens.PASS); }
    "return"   { log("[DEBUG] Reconhecido keyword: return"); return symbol(ChocoPyTokens.RETURN); }
    "while"    { log("[DEBUG] Reconhecido keyword: while"); return symbol(ChocoPyTokens.WHILE); }
    

    /*
        ":" -> seta q vai esperar um bloco de codigo entao vai esperar um INDENT
     */
    ":" {
        log("[DEBUG] Reconhecido delimitador: :");
        indentState.setExpectingBlockIndent(true);
        return symbol(ChocoPyTokens.COLON);
    }
    
    {ID} {
        log("[DEBUG] Reconhecido identificador: " + yytext());
        return symbol(ChocoPyTokens.ID, yytext());
    }

    

    {IntegerLiteral} { 
        try {          
            log("[DEBUG] Reconhecido número: " + yytext());
            BigInteger val = new BigInteger(yytext());
            BigInteger minInt = BigInteger.valueOf(Integer.MIN_VALUE);
            BigInteger maxInt = BigInteger.valueOf(Integer.MAX_VALUE);
            if (val.compareTo(minInt) < 0 || val.compareTo(maxInt) > 0) {
                log("[DEBUG] Integer literal fora do range: " + yytext());
                log("Erro Léxico: Integer literal fora do range [-2^31, 2^31-1]: " + yytext() + " na linha " + (yyline + 1));
                return symbol(ChocoPyTokens.UNRECOGNIZED, yytext()); 
            }
            log("[DEBUG] Reconhecido número: " + val);
            return symbol(ChocoPyTokens.NUMBER, val); 
        } catch (NumberFormatException e) {
            log("[DEBUG] Erro ao converter número: " + yytext() + ", erro: " + e.getMessage());
            return symbol(ChocoPyTokens.UNRECOGNIZED, "Illegal escape: " + yytext()); 
        }
    }
    /* Operators. */
    "+"  { log("[DEBUG] Reconhecido operador: +"); return symbol(ChocoPyTokens.PLUS); }
    "-"  { log("[DEBUG] Reconhecido operador: -"); return symbol(ChocoPyTokens.MINUS); }
    "*"  { log("[DEBUG] Reconhecido operador: *"); return symbol(ChocoPyTokens.TIMES); }
    "//" { log("[DEBUG] Reconhecido operador: //"); return symbol(ChocoPyTokens.FLOORDIV); }
    "%"  { log("[DEBUG] Reconhecido operador: %"); return symbol(ChocoPyTokens.MODULO); }
    "<"  { log("[DEBUG] Reconhecido operador: <"); return symbol(ChocoPyTokens.LT); }
    ">"  { log("[DEBUG] Reconhecido operador: >"); return symbol(ChocoPyTokens.GT); }
    "<=" { log("[DEBUG] Reconhecido operador: <="); return symbol(ChocoPyTokens.LE); }
    ">=" { log("[DEBUG] Reconhecido operador: >="); return symbol(ChocoPyTokens.GE); }
    "==" { log("[DEBUG] Reconhecido operador: =="); return symbol(ChocoPyTokens.EQ); }
    "!=" { log("[DEBUG] Reconhecido operador: !="); return symbol(ChocoPyTokens.NE); }
    "("  { log("[DEBUG] Reconhecido delimitador: ("); return symbol(ChocoPyTokens.LPAREN); }
    ")"  { log("[DEBUG] Reconhecido delimitador: )"); return symbol(ChocoPyTokens.RPAREN); }
    "["  { log("[DEBUG] Reconhecido delimitador: ["); return symbol(ChocoPyTokens.LBRACKET); }
    "]"  { log("[DEBUG] Reconhecido delimitador: ]"); return symbol(ChocoPyTokens.RBRACKET); }
    ","  { log("[DEBUG] Reconhecido delimitador: ,"); return symbol(ChocoPyTokens.COMMA); }
    "."  { log("[DEBUG] Reconhecido delimitador: ."); return symbol(ChocoPyTokens.DOT); }
    "="  { log("[DEBUG] Reconhecido delimitador: ="); return symbol(ChocoPyTokens.ASSIGN); }
    "->" { log("[DEBUG] Reconhecido delimitador: ->"); return symbol(ChocoPyTokens.ARROW); }

    /* Whitespace. no meio da linha */
    {WhiteSpace}+                {  /* ignore */ } 

    /* Comentários no meio da linha */
    "#" [^\r\n]*                {  /* ignore comment */ }

}


<STRING_STATE> {
   // --- Final da String ---
   \"           {
                    yybegin(YYINITIAL);
                    String content = string_buffer.toString();
                    // System.out.println("[DEBUG] String finalizada: '" + content + "'");

                    ComplexSymbolFactory.Location endLoc =
                        new ComplexSymbolFactory.Location(yyline + 1, yycolumn + yylength()); 
                    ComplexSymbolFactory.Location startLoc =
                        new ComplexSymbolFactory.Location(string_start_line + 1, string_start_col + 1);
                    if (ID_REGEX_PATTERN.matcher(content).matches()) {
                        log("[DEBUG] Classificada como IDSTRING, start=" + startLoc + ", end=" + endLoc);
                        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[ChocoPyTokens.IDSTRING],
                                                      ChocoPyTokens.IDSTRING,
                                                      startLoc, 
                                                      endLoc,   
                                                      content);
                    } else {
                        log("[DEBUG] Classificada como STRING normal, start=" + startLoc + ", end=" + endLoc);
                        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[ChocoPyTokens.STRING],
                                                      ChocoPyTokens.STRING,
                                                      startLoc, 
                                                      endLoc,   
                                                      content);
                    }
                }

   // --- Sequências de Escape Válidas ---
   \\\"         { log("[DEBUG] Escape válido em string: \\\""); string_buffer.append('"'); }
   \\\\         { log("[DEBUG] Escape válido em string: \\\\"); string_buffer.append('\\'); }
   \\n          { log("[DEBUG] Escape válido em string: \\n"); string_buffer.append('\n'); }
   \\t          { log("[DEBUG] Escape válido em string: \\t"); string_buffer.append('\t'); }

   // --- Caracteres Válidos Dentro da String ---
   {ValidStringChar} + {  string_buffer.append(yytext()); } //System.out.println("[DEBUG] Caracteres normais em string: '" + yytext() + "'");

   // --- Erros Dentro da String ---
   \\.          { // ERRO: Sequência de escape inválida
                   log("ERRO: Sequência de escape inválida em string: '" + yytext() + "'");
                   // Retorna UNRECOGNIZED mas consome o caractere inválido também
                   return symbol(ChocoPyTokens.UNRECOGNIZED,  "Illegal escape: " + yytext());
                 }
   \n | \r | \r\n { 
       log("ERRO: Quebra de linha não escapada em string");
       yybegin(YYINITIAL);
       yypushback(yylength());
       return symbol(ChocoPyTokens.UNRECOGNIZED, "<newline in string>");
   }
   // <<EOF>> dentro de STRING_STATE significa string não terminada
   <<EOF>>      {
                log("String não terminada no fim do arquivo");
                return symbol(ChocoPyTokens.UNRECOGNIZED, "<unterminated string>");

                 }


   // Caractere inválido dentro da string (fora do range ASCII 32-126 ou " ou \)
   [^]          {
                    log("Caractere inválido em string: '" + yytext() + "'");
                   return symbol(ChocoPyTokens.UNRECOGNIZED,  "Illegal escape: " + yytext());
                 }

} 

<INDENT_STATE> {
    // Consome os espaços em branco no início da linha e processa indentação
    {IndentChar}+ {
        String whitespace = yytext();
        log("Processando indentação: '" + whitespace + "'");
        handleIndentation(whitespace);
        if (!pendingTokens.isEmpty()) {
            return pendingTokens.removeFirst();
        }
        yybegin(YYINITIAL);
    }

    // Linhas apenas com comentário
    "#" [^\r\n]* {LineBreak} {
        log("Comentário em linha própria");
        handleBlankOrCommentLine();
        yybegin(INDENT_STATE); 
    }

    // Linha vazia (apenas quebra de linha)
    {LineBreak} {
        log("Linha vazia");
        handleBlankOrCommentLine();
      
    }

    // Qualquer outro caractere - não há indentação
    {NonIndentStart} {
        log("Conteúdo sem indentação no início da linha: '" + yytext() + "'");
        if (indentState.isLogicalLineStart()) {
            int currentIndent = 0; 
            int previousIndent = indentState.getIndentStack().peek();
            
            if (previousIndent > currentIndent) {
                log("Detectada necessidade de dedentação do nível " + previousIndent + " para " + currentIndent);
                handleDecreaseIndent(currentIndent);
                
                // tokens pendentes (DEDENTs) -> retornar o primeiro e manter o caractere atual na fila
                if (!pendingTokens.isEmpty()) {
                    yypushback(1); 
                    return pendingTokens.removeFirst();
                }
            }
            
            // não há necessidade de dedentação ou já processamos todos os DEDENTs
            needToProcessIndentation = true;
            pendingIndentation = "";
        } else {
            log("Não estamos no início de uma linha lógica, ignorando indentação");
        }
        
        yypushback(1); 
        yybegin(YYINITIAL); 
    }
}

/* --- Fim do Arquivo --- */
<<EOF>> {
    log("Encontrado EOF, chamando handleEOF()");
    handleEOF();
    // Se pendingTokens não estiver vazio após handleEOF()
    if (!pendingTokens.isEmpty()) {
        return pendingTokens.removeFirst();
    }
    // Caso contrário, retorna o token EOF real
    return symbol(ChocoPyTokens.EOF);
}


/* --- Erro Genérico Fallback --- */
/* Qualquer caractere não reconhecido pelas regras acima */
[^\n\r\u2028\u2029] {
    char c = yytext().charAt(0);
    int ascii = (int) c;
    String repr;
    if (c == '\n') {
        repr = "\\n";
    } else if (c == '\r') {
        repr = "\\r";
    } else if (c == '\t') {
        repr = "\\t";
    } else if (Character.isISOControl(c)) {
        repr = String.format("\\x%02X", ascii);
    } else {
        repr = Character.toString(c);
    }

    log("[DEBUG] ERRO: Caractere não reconhecido '" + repr + "' (ASCII=" + ascii + ") na linha " + (yyline + 1) + " coluna " + (yycolumn + 1));
    return symbol(ChocoPyTokens.UNRECOGNIZED, "Illegal character: " + repr);
}

