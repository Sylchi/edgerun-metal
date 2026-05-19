#include "wasm_compile.h"

static int erwc_push_token(ErWcParse* parse, ErWcTokenKind kind,
                           const char* start, size_t len, unsigned line) {
  ErWcToken* token;

  if (parse->token_count >= ERWC_MAX_TOKENS) {
    return -1;
  }
  token = &parse->tokens[parse->token_count++];
  token->kind = kind;
  token->start = start;
  token->len = len;
  token->line = line;
  return 0;
}

int erwc_tokenize(const ErWcSource* source, ErWcParse* parse) {
  size_t i = 0u;
  unsigned line = 1u;
  const char* data = (const char*)source->bytes;

  while (i < source->len) {
    char ch = data[i];

    if (ch == '\n') {
      ++line;
      ++i;
    } else if (ch == ' ' || ch == '\t' || ch == '\r') {
      ++i;
    } else if (ch == ';' && i + 1u < source->len && data[i + 1u] == ';') {
      i += 2u;
      while (i < source->len && data[i] != '\n') {
        ++i;
      }
    } else if (ch == '(') {
      if (erwc_push_token(parse, ERWC_TOKEN_LPAREN, data + i, 1u, line) != 0) {
        return -1;
      }
      ++i;
    } else if (ch == ')') {
      if (erwc_push_token(parse, ERWC_TOKEN_RPAREN, data + i, 1u, line) != 0) {
        return -1;
      }
      ++i;
    } else if (ch == '"') {
      size_t start = i + 1u;
      ++i;
      while (i < source->len && data[i] != '"') {
        if (data[i] == '\\') {
          return -1;
        }
        if (data[i] == '\n') {
          ++line;
        }
        ++i;
      }
      if (i >= source->len) {
        return -1;
      }
      if (erwc_push_token(parse, ERWC_TOKEN_STRING, data + start, i - start, line) != 0) {
        return -1;
      }
      ++i;
    } else {
      size_t start = i;
      while (i < source->len && data[i] != '(' && data[i] != ')' &&
             data[i] != ' ' && data[i] != '\t' && data[i] != '\r' &&
             data[i] != '\n') {
        ++i;
      }
      if (erwc_push_token(parse, ERWC_TOKEN_ATOM, data + start, i - start, line) != 0) {
        return -1;
      }
    }
  }
  return 0;
}

static int erwc_new_node(ErWcParse* parse, int is_list, int token) {
  ErWcNode* node;
  int index;

  if (parse->node_count >= ERWC_MAX_NODES) {
    return -1;
  }
  index = (int)parse->node_count++;
  node = &parse->nodes[index];
  node->is_list = is_list;
  node->token = token;
  node->first_child = -1;
  node->next_sibling = -1;
  return index;
}

static int erwc_parse_node(ErWcParse* parse, uint32_t* inout_token) {
  int node_index;

  if (*inout_token >= parse->token_count) {
    return -1;
  }
  if (parse->tokens[*inout_token].kind == ERWC_TOKEN_LPAREN) {
    int last_child = -1;
    ++(*inout_token);
    node_index = erwc_new_node(parse, 1, -1);
    if (node_index < 0) {
      return -1;
    }
    while (*inout_token < parse->token_count &&
           parse->tokens[*inout_token].kind != ERWC_TOKEN_RPAREN) {
      int child = erwc_parse_node(parse, inout_token);
      if (child < 0) {
        return -1;
      }
      if (last_child < 0) {
        parse->nodes[node_index].first_child = child;
      } else {
        parse->nodes[last_child].next_sibling = child;
      }
      last_child = child;
    }
    if (*inout_token >= parse->token_count ||
        parse->tokens[*inout_token].kind != ERWC_TOKEN_RPAREN) {
      return -1;
    }
    ++(*inout_token);
    return node_index;
  }
  if (parse->tokens[*inout_token].kind == ERWC_TOKEN_RPAREN) {
    return -1;
  }
  node_index = erwc_new_node(parse, 0, (int)*inout_token);
  ++(*inout_token);
  return node_index;
}

int erwc_parse_tree(ErWcParse* parse) {
  uint32_t token = 0u;
  int root = erwc_parse_node(parse, &token);

  if (root < 0 || token != parse->token_count) {
    return -1;
  }
  return root;
}

