class $PanicError extends Error {}
function $panic() {
  throw new $PanicError();
}
function $bound_check(arr, index) {
  if (index < 0 || index >= arr.length) throw new Error("Index out of bounds");
}
function $compare_int(a, b) {
  return (a >= b) - (a <= b);
}
function Result$Err$0$(param0) {
  this._0 = param0;
}
Result$Err$0$.prototype.$tag = 0;
function Result$Ok$0$(param0) {
  this._0 = param0;
}
Result$Ok$0$.prototype.$tag = 1;
const Error$mizchi$47$wite$47$types$46$WiteError$46$UnexpectedEof = { $tag: 5 };
const Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidMagic = { $tag: 4 };
function Error$mizchi$47$wite$47$types$46$WiteError$46$UnsupportedVersion(param0) {
  this._0 = param0;
}
Error$mizchi$47$wite$47$types$46$WiteError$46$UnsupportedVersion.prototype.$tag = 3;
function Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat(param0) {
  this._0 = param0;
}
Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat.prototype.$tag = 2;
const Error$moonbitlang$47$core$47$builtin$46$CreatingViewError$46$IndexOutOfBounds = { $tag: 1 };
const Error$moonbitlang$47$core$47$builtin$46$CreatingViewError$46$InvalidIndex = { $tag: 0 };
const _M0FP311moonbitlang4core7builtin20uint__to__string__js = (x, radix) => {
  return (x >>> 0).toString(radix);
};
function $makebytes(a, b) {
  const arr = new Uint8Array(a);
  if (b !== 0) {
    arr.fill(b);
  }
  return arr;
}
const _M0MP311moonbitlang4core7builtin7JSArray4push = (arr, val) => { arr.push(val); };
const $bytes_literal$0 = new Uint8Array();
function Result$Err$1$(param0) {
  this._0 = param0;
}
Result$Err$1$.prototype.$tag = 0;
function Result$Ok$1$(param0) {
  this._0 = param0;
}
Result$Ok$1$.prototype.$tag = 1;
function Result$Err$2$(param0) {
  this._0 = param0;
}
Result$Err$2$.prototype.$tag = 0;
function Result$Ok$2$(param0) {
  this._0 = param0;
}
Result$Ok$2$.prototype.$tag = 1;
function Result$Err$3$(param0) {
  this._0 = param0;
}
Result$Err$3$.prototype.$tag = 0;
function Result$Ok$3$(param0) {
  this._0 = param0;
}
Result$Ok$3$.prototype.$tag = 1;
function Result$Err$4$(param0) {
  this._0 = param0;
}
Result$Err$4$.prototype.$tag = 0;
function Result$Ok$4$(param0) {
  this._0 = param0;
}
Result$Ok$4$.prototype.$tag = 1;
function Result$Err$5$(param0) {
  this._0 = param0;
}
Result$Err$5$.prototype.$tag = 0;
function Result$Ok$5$(param0) {
  this._0 = param0;
}
Result$Ok$5$.prototype.$tag = 1;
function Result$Err$6$(param0) {
  this._0 = param0;
}
Result$Err$6$.prototype.$tag = 0;
function Result$Ok$6$(param0) {
  this._0 = param0;
}
Result$Ok$6$.prototype.$tag = 1;
function Result$Err$7$(param0) {
  this._0 = param0;
}
Result$Err$7$.prototype.$tag = 0;
function Result$Ok$7$(param0) {
  this._0 = param0;
}
Result$Ok$7$.prototype.$tag = 1;
function Result$Err$8$(param0) {
  this._0 = param0;
}
Result$Err$8$.prototype.$tag = 0;
function Result$Ok$8$(param0) {
  this._0 = param0;
}
Result$Ok$8$.prototype.$tag = 1;
function Result$Err$9$(param0) {
  this._0 = param0;
}
Result$Err$9$.prototype.$tag = 0;
function Result$Ok$9$(param0) {
  this._0 = param0;
}
Result$Ok$9$.prototype.$tag = 1;
const _M0FP095_40moonbitlang_2fcore_2fbuiltin_2eStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger = { method_0: _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger13write__string, method_1: _M0IP016_24default__implP311moonbitlang4core7builtin6Logger16write__substringGRP311moonbitlang4core7builtin13StringBuilderE, method_2: _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__view, method_3: _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__char };
const _M0FP36mizchi4wite12plugin_2dapi35json__string__array_2e_2abind_7c209 = ",";
const _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c232 = ",";
const _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c240 = ",";
const _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c243 = ",";
const _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c246 = ",";
const _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c247 = "";
function _M0FP311moonbitlang4core5abort5abortGRP311moonbitlang4core5bytes9BytesViewE(msg) {
  return $panic();
}
function _M0FP311moonbitlang4core5abort5abortGuE(msg) {
  $panic();
}
function _M0FP311moonbitlang4core7builtin5abortGRP311moonbitlang4core5bytes9BytesViewE(string, loc) {
  return _M0FP311moonbitlang4core5abort5abortGRP311moonbitlang4core5bytes9BytesViewE(`${string}\n  at ${_M0IP016_24default__implP311moonbitlang4core7builtin4Show10to__stringGRP311moonbitlang4core7builtin9SourceLocE(loc)}\n`);
}
function _M0FP311moonbitlang4core7builtin5abortGuE(string, loc) {
  _M0FP311moonbitlang4core5abort5abortGuE(`${string}\n  at ${_M0IP016_24default__implP311moonbitlang4core7builtin4Show10to__stringGRP311moonbitlang4core7builtin9SourceLocE(loc)}\n`);
}
function _M0MP311moonbitlang4core5array10FixedArray12unsafe__blitGyE(dst, dst_offset, src, src_offset, len) {
  if (dst === src && dst_offset < src_offset) {
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < len) {
        const _tmp$2 = dst_offset + i | 0;
        const _tmp$3 = src_offset + i | 0;
        $bound_check(src, _tmp$3);
        $bound_check(dst, _tmp$2);
        dst[_tmp$2] = src[_tmp$3];
        _tmp = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp = len - 1 | 0;
    while (true) {
      const i = _tmp;
      if (i >= 0) {
        const _tmp$2 = dst_offset + i | 0;
        const _tmp$3 = src_offset + i | 0;
        $bound_check(src, _tmp$3);
        $bound_check(dst, _tmp$2);
        dst[_tmp$2] = src[_tmp$3];
        _tmp = i - 1 | 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0MP311moonbitlang4core7builtin13StringBuilder11new_2einner(size_hint) {
  return { val: "" };
}
function _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__char(self, ch) {
  const _bind = self;
  _bind.val = `${_bind.val}${String.fromCodePoint(ch)}`;
}
function _M0MP311moonbitlang4core6uint166UInt1622is__leading__surrogate(self) {
  return _M0IP016_24default__implP311moonbitlang4core7builtin7Compare6op__geGkE(self, 55296) && _M0IP016_24default__implP311moonbitlang4core7builtin7Compare6op__leGkE(self, 56319);
}
function _M0MP311moonbitlang4core6uint166UInt1623is__trailing__surrogate(self) {
  return _M0IP016_24default__implP311moonbitlang4core7builtin7Compare6op__geGkE(self, 56320) && _M0IP016_24default__implP311moonbitlang4core7builtin7Compare6op__leGkE(self, 57343);
}
function _M0FP311moonbitlang4core7builtin32code__point__of__surrogate__pair(leading, trailing) {
  return (((Math.imul(leading - 55296 | 0, 1024) | 0) + trailing | 0) - 56320 | 0) + 65536 | 0;
}
function _M0MP311moonbitlang4core7builtin13SourceLocRepr5parse(repr) {
  const _bind = { str: repr, start: 0, end: repr.length };
  const _data = _bind.str;
  const _start = _bind.start;
  const _end = _start + (_bind.end - _bind.start | 0) | 0;
  let _cursor = _start;
  let accept_state = -1;
  let match_end = -1;
  let match_tag_saver_0 = -1;
  let match_tag_saver_1 = -1;
  let match_tag_saver_2 = -1;
  let match_tag_saver_3 = -1;
  let match_tag_saver_4 = -1;
  let tag_0 = -1;
  let tag_1 = -1;
  let tag_1_1 = -1;
  let tag_1_2 = -1;
  let tag_3 = -1;
  let tag_2 = -1;
  let tag_2_1 = -1;
  let tag_4 = -1;
  _L: {
    if (_cursor < _end) {
      const _p = _cursor;
      const next_char = _data.charCodeAt(_p);
      _cursor = _cursor + 1 | 0;
      if (next_char === 64) {
        _L$2: while (true) {
          tag_0 = _cursor;
          if (_cursor < _end) {
            const _p$2 = _cursor;
            const next_char$2 = _data.charCodeAt(_p$2);
            _cursor = _cursor + 1 | 0;
            if (next_char$2 === 58) {
              if (_cursor < _end) {
                const _p$3 = _cursor;
                _data.charCodeAt(_p$3);
                _cursor = _cursor + 1 | 0;
                let _tmp = 0;
                _L$3: while (true) {
                  const dispatch_15 = _tmp;
                  _L$4: {
                    _L$5: {
                      switch (dispatch_15) {
                        case 3: {
                          tag_1_2 = tag_1_1;
                          tag_1_1 = tag_1;
                          tag_1 = _cursor;
                          if (_cursor < _end) {
                            _L$6: {
                              const _p$4 = _cursor;
                              const next_char$3 = _data.charCodeAt(_p$4);
                              _cursor = _cursor + 1 | 0;
                              if (next_char$3 < 58) {
                                if (next_char$3 < 48) {
                                  break _L$6;
                                } else {
                                  tag_1 = _cursor;
                                  tag_2_1 = tag_2;
                                  tag_2 = _cursor;
                                  tag_3 = _cursor;
                                  if (_cursor < _end) {
                                    _L$7: {
                                      const _p$5 = _cursor;
                                      const next_char$4 = _data.charCodeAt(_p$5);
                                      _cursor = _cursor + 1 | 0;
                                      if (next_char$4 < 48) {
                                        if (next_char$4 === 45) {
                                          break _L$4;
                                        } else {
                                          break _L$7;
                                        }
                                      } else {
                                        if (next_char$4 > 57) {
                                          if (next_char$4 < 59) {
                                            _tmp = 3;
                                            continue _L$3;
                                          } else {
                                            break _L$7;
                                          }
                                        } else {
                                          _tmp = 6;
                                          continue _L$3;
                                        }
                                      }
                                    }
                                    _tmp = 0;
                                    continue _L$3;
                                  } else {
                                    break _L;
                                  }
                                }
                              } else {
                                if (next_char$3 > 58) {
                                  break _L$6;
                                } else {
                                  _tmp = 1;
                                  continue _L$3;
                                }
                              }
                            }
                            _tmp = 0;
                            continue _L$3;
                          } else {
                            break _L;
                          }
                        }
                        case 2: {
                          tag_1 = _cursor;
                          tag_2 = _cursor;
                          if (_cursor < _end) {
                            _L$6: {
                              const _p$4 = _cursor;
                              const next_char$3 = _data.charCodeAt(_p$4);
                              _cursor = _cursor + 1 | 0;
                              if (next_char$3 < 58) {
                                if (next_char$3 < 48) {
                                  break _L$6;
                                } else {
                                  _tmp = 2;
                                  continue _L$3;
                                }
                              } else {
                                if (next_char$3 > 58) {
                                  break _L$6;
                                } else {
                                  _tmp = 3;
                                  continue _L$3;
                                }
                              }
                            }
                            _tmp = 0;
                            continue _L$3;
                          } else {
                            break _L;
                          }
                        }
                        case 0: {
                          tag_1 = _cursor;
                          if (_cursor < _end) {
                            const _p$4 = _cursor;
                            const next_char$3 = _data.charCodeAt(_p$4);
                            _cursor = _cursor + 1 | 0;
                            if (next_char$3 === 58) {
                              _tmp = 1;
                              continue _L$3;
                            } else {
                              _tmp = 0;
                              continue _L$3;
                            }
                          } else {
                            break _L;
                          }
                        }
                        case 4: {
                          tag_1 = _cursor;
                          tag_4 = _cursor;
                          if (_cursor < _end) {
                            _L$6: {
                              const _p$4 = _cursor;
                              const next_char$3 = _data.charCodeAt(_p$4);
                              _cursor = _cursor + 1 | 0;
                              if (next_char$3 < 58) {
                                if (next_char$3 < 48) {
                                  break _L$6;
                                } else {
                                  _tmp = 4;
                                  continue _L$3;
                                }
                              } else {
                                if (next_char$3 > 58) {
                                  break _L$6;
                                } else {
                                  tag_1_2 = tag_1_1;
                                  tag_1_1 = tag_1;
                                  tag_1 = _cursor;
                                  if (_cursor < _end) {
                                    _L$7: {
                                      const _p$5 = _cursor;
                                      const next_char$4 = _data.charCodeAt(_p$5);
                                      _cursor = _cursor + 1 | 0;
                                      if (next_char$4 < 58) {
                                        if (next_char$4 < 48) {
                                          break _L$7;
                                        } else {
                                          tag_1 = _cursor;
                                          tag_2_1 = tag_2;
                                          tag_2 = _cursor;
                                          if (_cursor < _end) {
                                            _L$8: {
                                              const _p$6 = _cursor;
                                              const next_char$5 = _data.charCodeAt(_p$6);
                                              _cursor = _cursor + 1 | 0;
                                              if (next_char$5 < 58) {
                                                if (next_char$5 < 48) {
                                                  break _L$8;
                                                } else {
                                                  _tmp = 5;
                                                  continue _L$3;
                                                }
                                              } else {
                                                if (next_char$5 > 58) {
                                                  break _L$8;
                                                } else {
                                                  _tmp = 3;
                                                  continue _L$3;
                                                }
                                              }
                                            }
                                            _tmp = 0;
                                            continue _L$3;
                                          } else {
                                            break _L$5;
                                          }
                                        }
                                      } else {
                                        if (next_char$4 > 58) {
                                          break _L$7;
                                        } else {
                                          _tmp = 1;
                                          continue _L$3;
                                        }
                                      }
                                    }
                                    _tmp = 0;
                                    continue _L$3;
                                  } else {
                                    break _L;
                                  }
                                }
                              }
                            }
                            _tmp = 0;
                            continue _L$3;
                          } else {
                            break _L;
                          }
                        }
                        case 5: {
                          tag_1 = _cursor;
                          tag_2 = _cursor;
                          if (_cursor < _end) {
                            _L$6: {
                              const _p$4 = _cursor;
                              const next_char$3 = _data.charCodeAt(_p$4);
                              _cursor = _cursor + 1 | 0;
                              if (next_char$3 < 58) {
                                if (next_char$3 < 48) {
                                  break _L$6;
                                } else {
                                  _tmp = 5;
                                  continue _L$3;
                                }
                              } else {
                                if (next_char$3 > 58) {
                                  break _L$6;
                                } else {
                                  _tmp = 3;
                                  continue _L$3;
                                }
                              }
                            }
                            _tmp = 0;
                            continue _L$3;
                          } else {
                            break _L$5;
                          }
                        }
                        case 6: {
                          tag_1 = _cursor;
                          tag_2 = _cursor;
                          tag_3 = _cursor;
                          if (_cursor < _end) {
                            _L$6: {
                              const _p$4 = _cursor;
                              const next_char$3 = _data.charCodeAt(_p$4);
                              _cursor = _cursor + 1 | 0;
                              if (next_char$3 < 48) {
                                if (next_char$3 === 45) {
                                  break _L$4;
                                } else {
                                  break _L$6;
                                }
                              } else {
                                if (next_char$3 > 57) {
                                  if (next_char$3 < 59) {
                                    _tmp = 3;
                                    continue _L$3;
                                  } else {
                                    break _L$6;
                                  }
                                } else {
                                  _tmp = 6;
                                  continue _L$3;
                                }
                              }
                            }
                            _tmp = 0;
                            continue _L$3;
                          } else {
                            break _L;
                          }
                        }
                        case 1: {
                          tag_1_1 = tag_1;
                          tag_1 = _cursor;
                          if (_cursor < _end) {
                            _L$6: {
                              const _p$4 = _cursor;
                              const next_char$3 = _data.charCodeAt(_p$4);
                              _cursor = _cursor + 1 | 0;
                              if (next_char$3 < 58) {
                                if (next_char$3 < 48) {
                                  break _L$6;
                                } else {
                                  _tmp = 2;
                                  continue _L$3;
                                }
                              } else {
                                if (next_char$3 > 58) {
                                  break _L$6;
                                } else {
                                  _tmp = 1;
                                  continue _L$3;
                                }
                              }
                            }
                            _tmp = 0;
                            continue _L$3;
                          } else {
                            break _L;
                          }
                        }
                        default: {
                          break _L;
                        }
                      }
                    }
                    tag_1 = tag_1_2;
                    tag_2 = tag_2_1;
                    match_tag_saver_0 = tag_0;
                    match_tag_saver_1 = tag_1;
                    match_tag_saver_2 = tag_2;
                    match_tag_saver_3 = tag_3;
                    match_tag_saver_4 = tag_4;
                    accept_state = 0;
                    match_end = _cursor;
                    break _L;
                  }
                  tag_1_1 = tag_1_2;
                  tag_1 = _cursor;
                  tag_2 = tag_2_1;
                  if (_cursor < _end) {
                    _L$5: {
                      const _p$4 = _cursor;
                      const next_char$3 = _data.charCodeAt(_p$4);
                      _cursor = _cursor + 1 | 0;
                      if (next_char$3 < 58) {
                        if (next_char$3 < 48) {
                          break _L$5;
                        } else {
                          _tmp = 4;
                          continue;
                        }
                      } else {
                        if (next_char$3 > 58) {
                          break _L$5;
                        } else {
                          _tmp = 1;
                          continue;
                        }
                      }
                    }
                    _tmp = 0;
                    continue;
                  } else {
                    break _L;
                  }
                }
              } else {
                break _L;
              }
            } else {
              continue;
            }
          } else {
            break _L;
          }
        }
      } else {
        break _L;
      }
    } else {
      break _L;
    }
  }
  if (accept_state === 0) {
    let start_line;
    let _try_err;
    _L$2: {
      _L$3: {
        const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, match_tag_saver_1 + 1 | 0, match_tag_saver_2);
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          start_line = _ok._0;
        } else {
          const _err = _bind$2;
          _try_err = _err._0;
          break _L$3;
        }
        break _L$2;
      }
      start_line = $panic();
    }
    let start_column;
    let _try_err$2;
    _L$3: {
      _L$4: {
        const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, match_tag_saver_2 + 1 | 0, match_tag_saver_3);
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          start_column = _ok._0;
        } else {
          const _err = _bind$2;
          _try_err$2 = _err._0;
          break _L$4;
        }
        break _L$3;
      }
      start_column = $panic();
    }
    let pkg;
    let _try_err$3;
    _L$4: {
      _L$5: {
        const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, _start + 1 | 0, match_tag_saver_0);
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          pkg = _ok._0;
        } else {
          const _err = _bind$2;
          _try_err$3 = _err._0;
          break _L$5;
        }
        break _L$4;
      }
      pkg = $panic();
    }
    let filename;
    let _try_err$4;
    _L$5: {
      _L$6: {
        const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, match_tag_saver_0 + 1 | 0, match_tag_saver_1);
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          filename = _ok._0;
        } else {
          const _err = _bind$2;
          _try_err$4 = _err._0;
          break _L$6;
        }
        break _L$5;
      }
      filename = $panic();
    }
    let end_line;
    let _try_err$5;
    _L$6: {
      _L$7: {
        const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, match_tag_saver_3 + 1 | 0, match_tag_saver_4);
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          end_line = _ok._0;
        } else {
          const _err = _bind$2;
          _try_err$5 = _err._0;
          break _L$7;
        }
        break _L$6;
      }
      end_line = $panic();
    }
    let end_column;
    let _try_err$6;
    _L$7: {
      _L$8: {
        const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, match_tag_saver_4 + 1 | 0, match_end);
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          end_column = _ok._0;
        } else {
          const _err = _bind$2;
          _try_err$6 = _err._0;
          break _L$8;
        }
        break _L$7;
      }
      end_column = $panic();
    }
    return { pkg: pkg, filename: filename, start_line: start_line, start_column: start_column, end_line: end_line, end_column: end_column };
  } else {
    return $panic();
  }
}
function _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger13write__string(self, str) {
  const _bind = self;
  _bind.val = `${_bind.val}${str}`;
}
function _M0IP016_24default__implP311moonbitlang4core7builtin7Compare6op__leGkE(x, y) {
  return $compare_int(x, y) <= 0;
}
function _M0IP016_24default__implP311moonbitlang4core7builtin7Compare6op__geGkE(x, y) {
  return $compare_int(x, y) >= 0;
}
function _M0MP311moonbitlang4core6string6String11sub_2einner(self, start, end) {
  const len = self.length;
  let end$2;
  if (end === undefined) {
    end$2 = len;
  } else {
    const _Some = end;
    const _end = _Some;
    end$2 = _end < 0 ? len + _end | 0 : _end;
  }
  const start$2 = start < 0 ? len + start | 0 : start;
  if (start$2 >= 0 && (start$2 <= end$2 && end$2 <= len)) {
    if (start$2 < len && _M0MP311moonbitlang4core6uint166UInt1623is__trailing__surrogate(self.charCodeAt(start$2))) {
      return new Result$Err$0$(Error$moonbitlang$47$core$47$builtin$46$CreatingViewError$46$InvalidIndex);
    }
    if (end$2 < len && _M0MP311moonbitlang4core6uint166UInt1623is__trailing__surrogate(self.charCodeAt(end$2))) {
      return new Result$Err$0$(Error$moonbitlang$47$core$47$builtin$46$CreatingViewError$46$InvalidIndex);
    }
    return new Result$Ok$0$({ str: self, start: start$2, end: end$2 });
  } else {
    return new Result$Err$0$(Error$moonbitlang$47$core$47$builtin$46$CreatingViewError$46$IndexOutOfBounds);
  }
}
function _M0MP311moonbitlang4core6string6String3sub(self, start$46$opt, end) {
  let start;
  if (start$46$opt === undefined) {
    start = 0;
  } else {
    const _Some = start$46$opt;
    start = _Some;
  }
  return _M0MP311moonbitlang4core6string6String11sub_2einner(self, start, end);
}
function _M0IP016_24default__implP311moonbitlang4core7builtin6Logger16write__substringGRP311moonbitlang4core7builtin13StringBuilderE(self, value, start, len) {
  let _tmp;
  let _try_err;
  _L: {
    _L$2: {
      const _bind = _M0MP311moonbitlang4core6string6String11sub_2einner(value, start, start + len | 0);
      if (_bind.$tag === 1) {
        const _ok = _bind;
        _tmp = _ok._0;
      } else {
        const _err = _bind;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    _tmp = $panic();
  }
  _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__view(self, _tmp);
}
function _M0IP016_24default__implP311moonbitlang4core7builtin4Show10to__stringGRP311moonbitlang4core7builtin9SourceLocE(self) {
  const logger = _M0MP311moonbitlang4core7builtin13StringBuilder11new_2einner(0);
  _M0IP311moonbitlang4core7builtin9SourceLocP311moonbitlang4core7builtin4Show6output(self, { self: logger, method_table: _M0FP095_40moonbitlang_2fcore_2fbuiltin_2eStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return logger.val;
}
function _M0MP311moonbitlang4core7builtin4Iter4nextGcE(self) {
  const _func = self;
  return _func();
}
function _M0MP311moonbitlang4core7builtin4Iter4nextGyE(self) {
  const _func = self;
  return _func();
}
function _M0MP311moonbitlang4core4uint4UInt18to__string_2einner(self, radix) {
  return _M0FP311moonbitlang4core7builtin20uint__to__string__js(self, radix);
}
function _M0IP311moonbitlang4core6string10StringViewP311moonbitlang4core7builtin4Show10to__string(self) {
  return self.str.substring(self.start, self.end);
}
function _M0MP311moonbitlang4core6string6String11from__array(chars) {
  const buf = _M0MP311moonbitlang4core7builtin13StringBuilder11new_2einner(Math.imul(chars.end - chars.start | 0, 4) | 0);
  const _len = chars.end - chars.start | 0;
  let _tmp = 0;
  while (true) {
    const _i = _tmp;
    if (_i < _len) {
      const c = chars.buf[chars.start + _i | 0];
      _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__char(buf, c);
      _tmp = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return buf.val;
}
function _M0MP311moonbitlang4core6string6String24char__length__eq_2einner(self, len, start_offset, end_offset) {
  let end_offset$2;
  if (end_offset === undefined) {
    end_offset$2 = self.length;
  } else {
    const _Some = end_offset;
    end_offset$2 = _Some;
  }
  let _tmp = start_offset;
  let _tmp$2 = 0;
  while (true) {
    const index = _tmp;
    const count = _tmp$2;
    if (index < end_offset$2 && count < len) {
      const c1 = self.charCodeAt(index);
      if (_M0MP311moonbitlang4core6uint166UInt1622is__leading__surrogate(c1) && (index + 1 | 0) < end_offset$2) {
        const c2 = self.charCodeAt(index + 1 | 0);
        if (_M0MP311moonbitlang4core6uint166UInt1623is__trailing__surrogate(c2)) {
          _tmp = index + 2 | 0;
          _tmp$2 = count + 1 | 0;
          continue;
        } else {
          _M0FP311moonbitlang4core7builtin5abortGuE("invalid surrogate pair", "@moonbitlang/core/builtin:string.mbt:424:9-424:40");
        }
      }
      _tmp = index + 1 | 0;
      _tmp$2 = count + 1 | 0;
      continue;
    } else {
      return count === len && index === end_offset$2;
    }
  }
}
function _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__view(self, str) {
  const _bind = self;
  _bind.val = `${_bind.val}${_M0IP311moonbitlang4core6string10StringViewP311moonbitlang4core7builtin4Show10to__string(str)}`;
}
function _M0MP311moonbitlang4core5array5Array4pushGsE(self, value) {
  _M0MP311moonbitlang4core7builtin7JSArray4push(self, value);
}
function _M0MP311moonbitlang4core5array5Array4pushGcE(self, value) {
  _M0MP311moonbitlang4core7builtin7JSArray4push(self, value);
}
function _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite12plugin_2dapi7FuncSigE(self, value) {
  _M0MP311moonbitlang4core7builtin7JSArray4push(self, value);
}
function _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite12plugin_2dapi11ImportEntryE(self, value) {
  _M0MP311moonbitlang4core7builtin7JSArray4push(self, value);
}
function _M0MP311moonbitlang4core5array5Array4pushGjE(self, value) {
  _M0MP311moonbitlang4core7builtin7JSArray4push(self, value);
}
function _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite12plugin_2dapi11ExportEntryE(self, value) {
  _M0MP311moonbitlang4core7builtin7JSArray4push(self, value);
}
function _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite8optimize10RawSectionE(self, value) {
  _M0MP311moonbitlang4core7builtin7JSArray4push(self, value);
}
function _M0MP311moonbitlang4core6string6String4iter(self) {
  const len = self.length;
  const index = { val: 0 };
  const _p = () => {
    if (index.val < len) {
      const c1 = self.charCodeAt(index.val);
      if (_M0MP311moonbitlang4core6uint166UInt1622is__leading__surrogate(c1) && (index.val + 1 | 0) < len) {
        const c2 = self.charCodeAt(index.val + 1 | 0);
        if (_M0MP311moonbitlang4core6uint166UInt1623is__trailing__surrogate(c2)) {
          const c = _M0FP311moonbitlang4core7builtin32code__point__of__surrogate__pair(c1, c2);
          index.val = index.val + 2 | 0;
          return c;
        }
      }
      index.val = index.val + 1 | 0;
      return c1;
    } else {
      return -1;
    }
  };
  return _p;
}
function _M0IP311moonbitlang4core6string6StringP311moonbitlang4core7builtin12ToStringView16to__string__view(self) {
  return { str: self, start: 0, end: self.length };
}
function _M0MP311moonbitlang4core5bytes5Bytes4make(len, init) {
  if (len < 0) {
    return $bytes_literal$0;
  }
  return $makebytes(len, init);
}
function _M0MP311moonbitlang4core5bytes5Bytes3new(len) {
  return _M0MP311moonbitlang4core5bytes5Bytes4make(len, 0);
}
function _M0MP311moonbitlang4core3int3Int8to__char(self) {
  _L: {
    if (self >= 0 && self <= 55295) {
      break _L;
    } else {
      if (self >= 57344 && self <= 1114111) {
        break _L;
      } else {
        return -1;
      }
    }
  }
  return self;
}
function _M0MP311moonbitlang4core5bytes5Bytes12view_2einner(self, start, end) {
  const len = self.length;
  let end$2;
  if (end === undefined) {
    end$2 = len;
  } else {
    const _Some = end;
    const _end = _Some;
    end$2 = _end < 0 ? len + _end | 0 : _end;
  }
  const start$2 = start < 0 ? len + start | 0 : start;
  if (start$2 >= 0 && (start$2 <= end$2 && end$2 <= len)) {
    const _bind = end$2 - start$2 | 0;
    return { bytes: self, start: start$2, end: start$2 + _bind | 0 };
  } else {
    return _M0FP311moonbitlang4core7builtin5abortGRP311moonbitlang4core5bytes9BytesViewE("Invalid index for View", "@moonbitlang/core/builtin:bytesview.mbt:180:5-180:36");
  }
}
function _M0MP311moonbitlang4core5bytes9BytesView4iter(self) {
  const i = { val: 0 };
  const len = self.end - self.start | 0;
  const _p = () => {
    if (i.val < len) {
      const _p$2 = i.val;
      const _tmp = self.bytes;
      const _tmp$2 = self.start + _p$2 | 0;
      $bound_check(_tmp, _tmp$2);
      const result = _tmp[_tmp$2];
      i.val = i.val + 1 | 0;
      return result;
    } else {
      return -1;
    }
  };
  return _p;
}
function _M0MP311moonbitlang4core5array10FixedArray17blit__from__bytes(self, bytes_offset, src, src_offset, length) {
  const e1 = (bytes_offset + length | 0) - 1 | 0;
  const e2 = (src_offset + length | 0) - 1 | 0;
  const len1 = self.length;
  const len2 = src.length;
  if (length >= 0 && (bytes_offset >= 0 && (e1 < len1 && (src_offset >= 0 && e2 < len2)))) {
    _M0MP311moonbitlang4core5array10FixedArray12unsafe__blitGyE(self, bytes_offset, src, src_offset, length);
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MP311moonbitlang4core5bytes9BytesView9to__bytes(self) {
  if ((self.end - self.start | 0) === self.bytes.length) {
    return self.bytes;
  }
  const bytes = $makebytes(self.end - self.start | 0, 0);
  _M0MP311moonbitlang4core5array10FixedArray17blit__from__bytes(bytes, 0, self.bytes, self.start, self.end - self.start | 0);
  return bytes;
}
function _M0IP311moonbitlang4core7builtin13SourceLocReprP311moonbitlang4core7builtin4Show6output(self, logger) {
  const pkg = self.pkg;
  const _data = pkg.str;
  const _start = pkg.start;
  const _end = _start + (pkg.end - pkg.start | 0) | 0;
  let _cursor = _start;
  let accept_state = -1;
  let match_end = -1;
  let match_tag_saver_0 = -1;
  let tag_0 = -1;
  let _bind;
  _L: {
    _L$2: {
      _L$3: while (true) {
        if (_cursor < _end) {
          const _p = _cursor;
          const next_char = _data.charCodeAt(_p);
          _cursor = _cursor + 1 | 0;
          if (next_char === 47) {
            _L$4: while (true) {
              tag_0 = _cursor;
              if (_cursor < _end) {
                const _p$2 = _cursor;
                const next_char$2 = _data.charCodeAt(_p$2);
                _cursor = _cursor + 1 | 0;
                if (next_char$2 === 47) {
                  while (true) {
                    if (_cursor < _end) {
                      const _p$3 = _cursor;
                      _data.charCodeAt(_p$3);
                      _cursor = _cursor + 1 | 0;
                      continue;
                    } else {
                      match_tag_saver_0 = tag_0;
                      accept_state = 0;
                      match_end = _cursor;
                      break _L$2;
                    }
                  }
                } else {
                  continue;
                }
              } else {
                break _L$2;
              }
            }
          } else {
            continue;
          }
        } else {
          break _L$2;
        }
      }
      break _L;
    }
    if (accept_state === 0) {
      let package_name;
      let _try_err;
      _L$3: {
        _L$4: {
          const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, match_tag_saver_0 + 1 | 0, match_end);
          if (_bind$2.$tag === 1) {
            const _ok = _bind$2;
            package_name = _ok._0;
          } else {
            const _err = _bind$2;
            _try_err = _err._0;
            break _L$4;
          }
          break _L$3;
        }
        package_name = $panic();
      }
      let module_name;
      let _try_err$2;
      _L$4: {
        _L$5: {
          const _bind$2 = _M0MP311moonbitlang4core6string6String3sub(_data, _start, match_tag_saver_0);
          if (_bind$2.$tag === 1) {
            const _ok = _bind$2;
            module_name = _ok._0;
          } else {
            const _err = _bind$2;
            _try_err$2 = _err._0;
            break _L$5;
          }
          break _L$4;
        }
        module_name = $panic();
      }
      _bind = { _0: module_name, _1: package_name };
    } else {
      _bind = { _0: pkg, _1: undefined };
    }
  }
  const _module_name = _bind._0;
  const _package_name = _bind._1;
  if (_package_name === undefined) {
  } else {
    const _Some = _package_name;
    const _pkg_name = _Some;
    logger.method_table.method_2(logger.self, _pkg_name);
    logger.method_table.method_3(logger.self, 47);
  }
  logger.method_table.method_2(logger.self, self.filename);
  logger.method_table.method_3(logger.self, 58);
  logger.method_table.method_2(logger.self, self.start_line);
  logger.method_table.method_3(logger.self, 58);
  logger.method_table.method_2(logger.self, self.start_column);
  logger.method_table.method_3(logger.self, 45);
  logger.method_table.method_2(logger.self, self.end_line);
  logger.method_table.method_3(logger.self, 58);
  logger.method_table.method_2(logger.self, self.end_column);
  logger.method_table.method_3(logger.self, 64);
  logger.method_table.method_2(logger.self, _module_name);
}
function _M0IP311moonbitlang4core7builtin9SourceLocP311moonbitlang4core7builtin4Show6output(self, logger) {
  _M0IP311moonbitlang4core7builtin13SourceLocReprP311moonbitlang4core7builtin4Show6output(_M0MP311moonbitlang4core7builtin13SourceLocRepr5parse(self), logger);
}
function _M0MP311moonbitlang4core5array9ArrayView4joinGsE(self, separator) {
  if ((self.end - self.start | 0) === 0) {
    return "";
  } else {
    const _hd = self.buf[self.start];
    const _bind = self.buf;
    const _bind$2 = 1 + self.start | 0;
    const _bind$3 = self.end;
    const _x = { buf: _bind, start: _bind$2, end: _bind$3 };
    const hd = _M0IP311moonbitlang4core6string6StringP311moonbitlang4core7builtin12ToStringView16to__string__view(_hd);
    let size_hint = hd.end - hd.start | 0;
    const _len = _x.end - _x.start | 0;
    let _tmp = 0;
    while (true) {
      const _i = _tmp;
      if (_i < _len) {
        const s = _bind[_bind$2 + _i | 0];
        const _tmp$2 = size_hint;
        const _p = _M0IP311moonbitlang4core6string6StringP311moonbitlang4core7builtin12ToStringView16to__string__view(s);
        size_hint = _tmp$2 + ((_p.end - _p.start | 0) + (separator.end - separator.start | 0) | 0) | 0;
        _tmp = _i + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    size_hint = size_hint << 1;
    const buf = _M0MP311moonbitlang4core7builtin13StringBuilder11new_2einner(size_hint);
    _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__view(buf, hd);
    if (_M0MP311moonbitlang4core6string6String24char__length__eq_2einner(separator.str, 0, separator.start, separator.end)) {
      const _len$2 = _x.end - _x.start | 0;
      let _tmp$2 = 0;
      while (true) {
        const _i = _tmp$2;
        if (_i < _len$2) {
          const s = _bind[_bind$2 + _i | 0];
          const s$2 = _M0IP311moonbitlang4core6string6StringP311moonbitlang4core7builtin12ToStringView16to__string__view(s);
          _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__view(buf, s$2);
          _tmp$2 = _i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    } else {
      const _len$2 = _x.end - _x.start | 0;
      let _tmp$2 = 0;
      while (true) {
        const _i = _tmp$2;
        if (_i < _len$2) {
          const s = _bind[_bind$2 + _i | 0];
          const s$2 = _M0IP311moonbitlang4core6string6StringP311moonbitlang4core7builtin12ToStringView16to__string__view(s);
          _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__view(buf, separator);
          _M0IP311moonbitlang4core7builtin13StringBuilderP311moonbitlang4core7builtin6Logger11write__view(buf, s$2);
          _tmp$2 = _i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    }
    return buf.val;
  }
}
function _M0MP311moonbitlang4core5array5Array4joinGsE(self, separator) {
  return _M0MP311moonbitlang4core5array9ArrayView4joinGsE({ buf: self, start: 0, end: self.length }, separator);
}
function _M0FP36mizchi4wite5types23wite__error__to__string(err) {
  switch (err.$tag) {
    case 5: {
      return "unexpected eof";
    }
    case 4: {
      return "invalid wasm magic";
    }
    case 3: {
      const _UnsupportedVersion = err;
      const _msg = _UnsupportedVersion._0;
      return `unsupported version: ${_msg}`;
    }
    default: {
      const _InvalidFormat = err;
      const _msg$2 = _InvalidFormat._0;
      return `invalid format: ${_msg$2}`;
    }
  }
}
function _M0FP36mizchi4wite5types17error__to__string(err) {
  return _M0FP36mizchi4wite5types23wite__error__to__string(err);
}
function _M0MP36mizchi4wite8optimize6Cursor3new(bytes) {
  return { bytes: bytes, pos: 0 };
}
function _M0MP36mizchi4wite8optimize6Cursor10read__byte(self) {
  if (self.pos < self.bytes.length) {
    const b = self.bytes[self.pos];
    self.pos = self.pos + 1 | 0;
    return new Result$Ok$1$(b);
  } else {
    return new Result$Err$1$(Error$mizchi$47$wite$47$types$46$WiteError$46$UnexpectedEof);
  }
}
function _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(self) {
  let shift;
  let result;
  _L: {
    shift = 0;
    result = 0;
    break _L;
  }
  let _tmp = shift;
  let _tmp$2 = result;
  while (true) {
    const shift$2 = _tmp;
    const result$2 = _tmp$2;
    const _bind = _M0MP36mizchi4wite8optimize6Cursor10read__byte(self);
    let byte;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      byte = _ok._0;
    } else {
      return _bind;
    }
    let _tmp$3;
    if (shift$2 >= 28) {
      const _p = 128;
      _tmp$3 = (byte & _p & 255) !== 0;
    } else {
      _tmp$3 = false;
    }
    if (_tmp$3) {
      return new Result$Err$2$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat("LEB128 u32 overflow"));
    }
    if (shift$2 >= 28 && byte > 15) {
      return new Result$Err$2$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat("LEB128 u32 value overflow"));
    }
    const _p = 127;
    const _p$2 = byte & _p & 255;
    const value = _p$2 << shift$2;
    const next = result$2 | value;
    const _p$3 = 128;
    const _p$4 = byte & _p$3 & 255;
    const _p$5 = 0;
    if (_p$4 === _p$5) {
      return new Result$Ok$2$(next);
    } else {
      _tmp = shift$2 + 7 | 0;
      _tmp$2 = next;
      continue;
    }
  }
}
function _M0MP36mizchi4wite8optimize6Cursor8set__pos(self, pos) {
  self.pos = pos;
}
function _M0MP36mizchi4wite8optimize6Cursor4skip(self, n) {
  if (n < 0) {
    return new Result$Err$3$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat("negative skip"));
  }
  if ((self.pos + n | 0) <= self.bytes.length) {
    self.pos = self.pos + n | 0;
    return new Result$Ok$3$(undefined);
  } else {
    return new Result$Err$3$(Error$mizchi$47$wite$47$types$46$WiteError$46$UnexpectedEof);
  }
}
function _M0FP36mizchi4wite8optimize20ensure__core__header(bytes) {
  if (bytes.length < 8) {
    return new Result$Err$3$(Error$mizchi$47$wite$47$types$46$WiteError$46$UnexpectedEof);
  }
  let _tmp;
  $bound_check(bytes, 0);
  const _tmp$2 = bytes[0];
  const _p = 0;
  if (_tmp$2 !== (_p & 255)) {
    _tmp = true;
  } else {
    let _tmp$3;
    $bound_check(bytes, 1);
    const _tmp$4 = bytes[1];
    const _p$2 = 97;
    if (_tmp$4 !== (_p$2 & 255)) {
      _tmp$3 = true;
    } else {
      let _tmp$5;
      $bound_check(bytes, 2);
      const _tmp$6 = bytes[2];
      const _p$3 = 115;
      if (_tmp$6 !== (_p$3 & 255)) {
        _tmp$5 = true;
      } else {
        $bound_check(bytes, 3);
        const _tmp$7 = bytes[3];
        const _p$4 = 109;
        _tmp$5 = _tmp$7 !== (_p$4 & 255);
      }
      _tmp$3 = _tmp$5;
    }
    _tmp = _tmp$3;
  }
  if (_tmp) {
    return new Result$Err$3$(Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidMagic);
  }
  let _tmp$3;
  $bound_check(bytes, 4);
  const _tmp$4 = bytes[4];
  const _p$2 = 1;
  if (_tmp$4 !== (_p$2 & 255)) {
    _tmp$3 = true;
  } else {
    let _tmp$5;
    $bound_check(bytes, 5);
    const _tmp$6 = bytes[5];
    const _p$3 = 0;
    if (_tmp$6 !== (_p$3 & 255)) {
      _tmp$5 = true;
    } else {
      let _tmp$7;
      $bound_check(bytes, 6);
      const _tmp$8 = bytes[6];
      const _p$4 = 0;
      if (_tmp$8 !== (_p$4 & 255)) {
        _tmp$7 = true;
      } else {
        $bound_check(bytes, 7);
        const _tmp$9 = bytes[7];
        const _p$5 = 0;
        _tmp$7 = _tmp$9 !== (_p$5 & 255);
      }
      _tmp$5 = _tmp$7;
    }
    _tmp$3 = _tmp$5;
  }
  if (_tmp$3) {
    return new Result$Err$3$(new Error$mizchi$47$wite$47$types$46$WiteError$46$UnsupportedVersion("expected core wasm version 1"));
  } else {
    return new Result$Ok$3$(undefined);
  }
}
function _M0FP36mizchi4wite8optimize28parse__custom__section__name(payload) {
  const parser = _M0MP36mizchi4wite8optimize6Cursor3new(payload);
  const _bind = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  let name_len_u;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    name_len_u = _ok._0;
  } else {
    return _bind;
  }
  const name_len = name_len_u;
  if (name_len < 0) {
    return new Result$Err$4$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat("custom section name length overflow"));
  }
  const start = parser.pos;
  const end_ = start + name_len | 0;
  if (end_ > payload.length) {
    return new Result$Err$4$(Error$mizchi$47$wite$47$types$46$WiteError$46$UnexpectedEof);
  }
  const out = [];
  const _it = _M0MP311moonbitlang4core5bytes9BytesView4iter(_M0MP311moonbitlang4core5bytes5Bytes12view_2einner(payload, start, end_));
  while (true) {
    const _bind$2 = _M0MP311moonbitlang4core7builtin4Iter4nextGyE(_it);
    if (_bind$2 === -1) {
      break;
    } else {
      const _Some = _bind$2;
      const _b = _Some;
      const _bind$3 = _M0MP311moonbitlang4core3int3Int8to__char(_b);
      if (_bind$3 === -1) {
        _M0MP311moonbitlang4core5array5Array4pushGcE(out, 63);
      } else {
        const _Some$2 = _bind$3;
        const _ch = _Some$2;
        _M0MP311moonbitlang4core5array5Array4pushGcE(out, _ch);
      }
      continue;
    }
  }
  return new Result$Ok$4$(_M0MP311moonbitlang4core6string6String11from__array({ buf: out, start: 0, end: out.length }));
}
function _M0FP36mizchi4wite8optimize21parse__sections__from(bytes, start) {
  const parser = _M0MP36mizchi4wite8optimize6Cursor3new(bytes);
  _M0MP36mizchi4wite8optimize6Cursor8set__pos(parser, start);
  const sections = [];
  while (true) {
    if (!(parser.pos >= parser.bytes.length)) {
      const section_start = parser.pos;
      const _bind = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
      let _p;
      if (_bind.$tag === 1) {
        const _ok = _bind;
        _p = _ok._0;
      } else {
        return _bind;
      }
      const section_id = _p;
      const _bind$2 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
      let payload_size_u;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        payload_size_u = _ok._0;
      } else {
        return _bind$2;
      }
      const payload_size = payload_size_u;
      if (payload_size < 0) {
        return new Result$Err$5$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat("section size overflow"));
      }
      const payload_start = parser.pos;
      const section_end = payload_start + payload_size | 0;
      if (section_end > bytes.length) {
        return new Result$Err$5$(Error$mizchi$47$wite$47$types$46$WiteError$46$UnexpectedEof);
      }
      let custom_name;
      if (section_id === 0) {
        const payload = _M0MP311moonbitlang4core5bytes9BytesView9to__bytes(_M0MP311moonbitlang4core5bytes5Bytes12view_2einner(bytes, payload_start, section_end));
        const _bind$3 = _M0FP36mizchi4wite8optimize28parse__custom__section__name(payload);
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          custom_name = _ok._0;
        } else {
          return _bind$3;
        }
      } else {
        custom_name = undefined;
      }
      _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite8optimize10RawSectionE(sections, { section_id: section_id, section_start: section_start, payload_start: payload_start, section_end: section_end, custom_name: custom_name });
      _M0MP36mizchi4wite8optimize6Cursor8set__pos(parser, section_end);
      continue;
    } else {
      break;
    }
  }
  return new Result$Ok$5$(sections);
}
function _M0FP36mizchi4wite8optimize28parse__core__sections__raise(bytes) {
  const _bind = _M0FP36mizchi4wite8optimize20ensure__core__header(bytes);
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _ok._0;
  } else {
    return _bind;
  }
  return _M0FP36mizchi4wite8optimize21parse__sections__from(bytes, 8);
}
function _M0FP36mizchi4wite8optimize25ensure__component__header(bytes) {
  if (bytes.length < 8) {
    return new Result$Err$3$(Error$mizchi$47$wite$47$types$46$WiteError$46$UnexpectedEof);
  }
  let _tmp;
  $bound_check(bytes, 0);
  const _tmp$2 = bytes[0];
  const _p = 0;
  if (_tmp$2 !== (_p & 255)) {
    _tmp = true;
  } else {
    let _tmp$3;
    $bound_check(bytes, 1);
    const _tmp$4 = bytes[1];
    const _p$2 = 97;
    if (_tmp$4 !== (_p$2 & 255)) {
      _tmp$3 = true;
    } else {
      let _tmp$5;
      $bound_check(bytes, 2);
      const _tmp$6 = bytes[2];
      const _p$3 = 115;
      if (_tmp$6 !== (_p$3 & 255)) {
        _tmp$5 = true;
      } else {
        $bound_check(bytes, 3);
        const _tmp$7 = bytes[3];
        const _p$4 = 109;
        _tmp$5 = _tmp$7 !== (_p$4 & 255);
      }
      _tmp$3 = _tmp$5;
    }
    _tmp = _tmp$3;
  }
  if (_tmp) {
    return new Result$Err$3$(Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidMagic);
  }
  let _tmp$3;
  $bound_check(bytes, 4);
  const _tmp$4 = bytes[4];
  const _p$2 = 13;
  if (_tmp$4 !== (_p$2 & 255)) {
    _tmp$3 = true;
  } else {
    let _tmp$5;
    $bound_check(bytes, 5);
    const _tmp$6 = bytes[5];
    const _p$3 = 0;
    if (_tmp$6 !== (_p$3 & 255)) {
      _tmp$5 = true;
    } else {
      let _tmp$7;
      $bound_check(bytes, 6);
      const _tmp$8 = bytes[6];
      const _p$4 = 1;
      if (_tmp$8 !== (_p$4 & 255)) {
        _tmp$7 = true;
      } else {
        $bound_check(bytes, 7);
        const _tmp$9 = bytes[7];
        const _p$5 = 0;
        _tmp$7 = _tmp$9 !== (_p$5 & 255);
      }
      _tmp$5 = _tmp$7;
    }
    _tmp$3 = _tmp$5;
  }
  if (_tmp$3) {
    return new Result$Err$3$(new Error$mizchi$47$wite$47$types$46$WiteError$46$UnsupportedVersion("expected component wasm header 0d 00 01 00"));
  } else {
    return new Result$Ok$3$(undefined);
  }
}
function _M0FP36mizchi4wite8optimize33parse__component__sections__raise(bytes) {
  const _bind = _M0FP36mizchi4wite8optimize25ensure__component__header(bytes);
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _ok._0;
  } else {
    return _bind;
  }
  return _M0FP36mizchi4wite8optimize21parse__sections__from(bytes, 8);
}
function _M0FP36mizchi4wite12plugin_2dapi15val__type__name(b) {
  const _bind = b;
  switch (_bind) {
    case 127: {
      return "i32";
    }
    case 126: {
      return "i64";
    }
    case 125: {
      return "f32";
    }
    case 124: {
      return "f64";
    }
    case 123: {
      return "v128";
    }
    case 112: {
      return "funcref";
    }
    case 111: {
      return "externref";
    }
    default: {
      return "unknown";
    }
  }
}
function _M0FP36mizchi4wite12plugin_2dapi18export__kind__name(kind) {
  switch (kind) {
    case 0: {
      return "function";
    }
    case 1: {
      return "table";
    }
    case 2: {
      return "memory";
    }
    case 3: {
      return "global";
    }
    default: {
      return "unknown";
    }
  }
}
function _M0FP36mizchi4wite12plugin_2dapi18import__kind__name(kind) {
  switch (kind) {
    case 0: {
      return "function";
    }
    case 1: {
      return "table";
    }
    case 2: {
      return "memory";
    }
    case 3: {
      return "global";
    }
    case 4: {
      return "tag";
    }
    default: {
      return "unknown";
    }
  }
}
function _M0FP36mizchi4wite12plugin_2dapi20escape__json__string(s) {
  const out = [];
  const _it = _M0MP311moonbitlang4core6string6String4iter(s);
  while (true) {
    const _bind = _M0MP311moonbitlang4core7builtin4Iter4nextGcE(_it);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _ch = _Some;
      switch (_ch) {
        case 34: {
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 92);
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 34);
          break;
        }
        case 92: {
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 92);
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 92);
          break;
        }
        case 10: {
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 92);
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 110);
          break;
        }
        case 13: {
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 92);
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 114);
          break;
        }
        case 9: {
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 92);
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, 116);
          break;
        }
        default: {
          _M0MP311moonbitlang4core5array5Array4pushGcE(out, _ch);
        }
      }
      continue;
    }
  }
  return _M0MP311moonbitlang4core6string6String11from__array({ buf: out, start: 0, end: out.length });
}
function _M0FP36mizchi4wite12plugin_2dapi21is__component__header(bytes) {
  if (bytes.length >= 8) {
    let _tmp;
    $bound_check(bytes, 0);
    const _p = bytes[0];
    const _p$2 = 0;
    if (_p === _p$2) {
      let _tmp$2;
      $bound_check(bytes, 1);
      const _p$3 = bytes[1];
      const _p$4 = 97;
      if (_p$3 === _p$4) {
        let _tmp$3;
        $bound_check(bytes, 2);
        const _p$5 = bytes[2];
        const _p$6 = 115;
        if (_p$5 === _p$6) {
          let _tmp$4;
          $bound_check(bytes, 3);
          const _p$7 = bytes[3];
          const _p$8 = 109;
          if (_p$7 === _p$8) {
            let _tmp$5;
            $bound_check(bytes, 4);
            const _p$9 = bytes[4];
            const _p$10 = 13;
            if (_p$9 === _p$10) {
              let _tmp$6;
              $bound_check(bytes, 5);
              const _p$11 = bytes[5];
              const _p$12 = 0;
              if (_p$11 === _p$12) {
                let _tmp$7;
                $bound_check(bytes, 6);
                const _p$13 = bytes[6];
                const _p$14 = 1;
                if (_p$13 === _p$14) {
                  $bound_check(bytes, 7);
                  const _p$15 = bytes[7];
                  const _p$16 = 0;
                  _tmp$7 = _p$15 === _p$16;
                } else {
                  _tmp$7 = false;
                }
                _tmp$6 = _tmp$7;
              } else {
                _tmp$6 = false;
              }
              _tmp$5 = _tmp$6;
            } else {
              _tmp$5 = false;
            }
            _tmp$4 = _tmp$5;
          } else {
            _tmp$4 = false;
          }
          _tmp$3 = _tmp$4;
        } else {
          _tmp$3 = false;
        }
        _tmp$2 = _tmp$3;
      } else {
        _tmp$2 = false;
      }
      _tmp = _tmp$2;
    } else {
      _tmp = false;
    }
    return _tmp;
  } else {
    return false;
  }
}
function _M0FP36mizchi4wite12plugin_2dapi10read__name(parser) {
  const _bind = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  let name_len;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    name_len = _ok._0;
  } else {
    return _bind;
  }
  const name_len_int = name_len;
  if (name_len_int < 0) {
    return new Result$Err$4$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat("name length overflow"));
  }
  const start = parser.pos;
  const end_ = start + name_len_int | 0;
  const _bind$2 = _M0MP36mizchi4wite8optimize6Cursor4skip(parser, name_len_int);
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    _ok._0;
  } else {
    return _bind$2;
  }
  const out = [];
  let _tmp = start;
  while (true) {
    const i = _tmp;
    if (i < end_) {
      const _bind$3 = _M0MP311moonbitlang4core3int3Int8to__char(parser.bytes[i]);
      if (_bind$3 === -1) {
        _M0MP311moonbitlang4core5array5Array4pushGcE(out, 63);
      } else {
        const _Some = _bind$3;
        const _ch = _Some;
        _M0MP311moonbitlang4core5array5Array4pushGcE(out, _ch);
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new Result$Ok$4$(_M0MP311moonbitlang4core6string6String11from__array({ buf: out, start: 0, end: out.length }));
}
function _M0FP36mizchi4wite12plugin_2dapi20parse__exports__full(payload) {
  const parser = _M0MP36mizchi4wite8optimize6Cursor3new(payload);
  const _bind = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  let count;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    count = _ok._0;
  } else {
    return _bind;
  }
  const out = [];
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ >>> 0 < count >>> 0) {
      const _bind$2 = _M0FP36mizchi4wite12plugin_2dapi10read__name(parser);
      let name;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        name = _ok._0;
      } else {
        return _bind$2;
      }
      const _bind$3 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
      let _p;
      if (_bind$3.$tag === 1) {
        const _ok = _bind$3;
        _p = _ok._0;
      } else {
        return _bind$3;
      }
      const kind = _p;
      const _bind$4 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
      let index;
      if (_bind$4.$tag === 1) {
        const _ok = _bind$4;
        index = _ok._0;
      } else {
        return _bind$4;
      }
      _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite12plugin_2dapi11ExportEntryE(out, { name: name, kind: kind, index: index });
      _tmp = (_ >>> 0) + (1 >>> 0) | 0;
      continue;
    } else {
      break;
    }
  }
  return new Result$Ok$6$(out);
}
function _M0FP36mizchi4wite12plugin_2dapi12skip__limits(parser) {
  const _bind = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  let flags;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    flags = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    _ok._0;
  } else {
    return _bind$2;
  }
  if ((flags & 1) !== 0) {
    const _bind$3 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      _ok._0;
    } else {
      return _bind$3;
    }
  }
  return new Result$Ok$3$(undefined);
}
function _M0FP36mizchi4wite12plugin_2dapi16skip__heap__type(parser) {
  const _bind = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
  let first;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    first = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = first;
  switch (_bind$2) {
    case 112: {
      break;
    }
    case 111: {
      break;
    }
    default: {
      const _p = 128;
      if ((first & _p & 255) !== 0) {
        let consumed = 1;
        while (true) {
          const _bind$3 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
          let b;
          if (_bind$3.$tag === 1) {
            const _ok = _bind$3;
            b = _ok._0;
          } else {
            return _bind$3;
          }
          consumed = consumed + 1 | 0;
          if (consumed > 5) {
            return new Result$Err$3$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat("heap type overflow"));
          }
          const _p$2 = 128;
          const _p$3 = b & _p$2 & 255;
          const _p$4 = 0;
          if (_p$3 === _p$4) {
            break;
          }
          continue;
        }
      }
    }
  }
  return new Result$Ok$3$(undefined);
}
function _M0FP36mizchi4wite12plugin_2dapi20parse__imports__full(payload) {
  const parser = _M0MP36mizchi4wite8optimize6Cursor3new(payload);
  const _bind = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  let count;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    count = _ok._0;
  } else {
    return _bind;
  }
  const out = [];
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ >>> 0 < count >>> 0) {
      const _bind$2 = _M0FP36mizchi4wite12plugin_2dapi10read__name(parser);
      let mod_name;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        mod_name = _ok._0;
      } else {
        return _bind$2;
      }
      const _bind$3 = _M0FP36mizchi4wite12plugin_2dapi10read__name(parser);
      let name;
      if (_bind$3.$tag === 1) {
        const _ok = _bind$3;
        name = _ok._0;
      } else {
        return _bind$3;
      }
      const _bind$4 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
      let _p;
      if (_bind$4.$tag === 1) {
        const _ok = _bind$4;
        _p = _ok._0;
      } else {
        return _bind$4;
      }
      const kind = _p;
      let type_index;
      switch (kind) {
        case 0: {
          const _bind$5 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
          let idx;
          if (_bind$5.$tag === 1) {
            const _ok = _bind$5;
            idx = _ok._0;
          } else {
            return _bind$5;
          }
          type_index = idx;
          break;
        }
        case 1: {
          const _bind$6 = _M0FP36mizchi4wite12plugin_2dapi16skip__heap__type(parser);
          if (_bind$6.$tag === 1) {
            const _ok = _bind$6;
            _ok._0;
          } else {
            return _bind$6;
          }
          const _bind$7 = _M0FP36mizchi4wite12plugin_2dapi12skip__limits(parser);
          if (_bind$7.$tag === 1) {
            const _ok = _bind$7;
            _ok._0;
          } else {
            return _bind$7;
          }
          type_index = undefined;
          break;
        }
        case 2: {
          const _bind$8 = _M0FP36mizchi4wite12plugin_2dapi12skip__limits(parser);
          if (_bind$8.$tag === 1) {
            const _ok = _bind$8;
            _ok._0;
          } else {
            return _bind$8;
          }
          type_index = undefined;
          break;
        }
        case 3: {
          const _bind$9 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
          if (_bind$9.$tag === 1) {
            const _ok = _bind$9;
            _ok._0;
          } else {
            return _bind$9;
          }
          const _bind$10 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
          if (_bind$10.$tag === 1) {
            const _ok = _bind$10;
            _ok._0;
          } else {
            return _bind$10;
          }
          type_index = undefined;
          break;
        }
        case 4: {
          const _bind$11 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
          if (_bind$11.$tag === 1) {
            const _ok = _bind$11;
            _ok._0;
          } else {
            return _bind$11;
          }
          const _bind$12 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
          if (_bind$12.$tag === 1) {
            const _ok = _bind$12;
            _ok._0;
          } else {
            return _bind$12;
          }
          type_index = undefined;
          break;
        }
        default: {
          return new Result$Err$7$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat(`unsupported import kind: ${_M0MP311moonbitlang4core4uint4UInt18to__string_2einner(kind, 10)}`));
        }
      }
      _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite12plugin_2dapi11ImportEntryE(out, { mod_name: mod_name, name: name, kind: kind, type_index: type_index });
      _tmp = (_ >>> 0) + (1 >>> 0) | 0;
      continue;
    } else {
      break;
    }
  }
  return new Result$Ok$7$(out);
}
function _M0FP36mizchi4wite12plugin_2dapi18parse__func__types(payload) {
  const parser = _M0MP36mizchi4wite8optimize6Cursor3new(payload);
  const _bind = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  let count;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    count = _ok._0;
  } else {
    return _bind;
  }
  const out = [];
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ >>> 0 < count >>> 0) {
      _L: {
        const _bind$2 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
        let _p;
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          _p = _ok._0;
        } else {
          return _bind$2;
        }
        const form = _p;
        if (form !== 96) {
          _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite12plugin_2dapi7FuncSigE(out, { params: [], results: [] });
          switch (form) {
            case 95: {
              const _bind$3 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
              let field_count;
              if (_bind$3.$tag === 1) {
                const _ok = _bind$3;
                field_count = _ok._0;
              } else {
                return _bind$3;
              }
              let _tmp$2 = 0;
              while (true) {
                const _$2 = _tmp$2;
                if (_$2 >>> 0 < field_count >>> 0) {
                  const _bind$4 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
                  if (_bind$4.$tag === 1) {
                    const _ok = _bind$4;
                    _ok._0;
                  } else {
                    return _bind$4;
                  }
                  const _bind$5 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
                  if (_bind$5.$tag === 1) {
                    const _ok = _bind$5;
                    _ok._0;
                  } else {
                    return _bind$5;
                  }
                  _tmp$2 = (_$2 >>> 0) + (1 >>> 0) | 0;
                  continue;
                } else {
                  break;
                }
              }
              break;
            }
            case 94: {
              const _bind$4 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
              if (_bind$4.$tag === 1) {
                const _ok = _bind$4;
                _ok._0;
              } else {
                return _bind$4;
              }
              const _bind$5 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
              if (_bind$5.$tag === 1) {
                const _ok = _bind$5;
                _ok._0;
              } else {
                return _bind$5;
              }
              break;
            }
            default: {
              return new Result$Err$8$(new Error$mizchi$47$wite$47$types$46$WiteError$46$InvalidFormat(`unsupported type form: ${_M0MP311moonbitlang4core4uint4UInt18to__string_2einner(form, 10)}`));
            }
          }
          break _L;
        }
        const _bind$3 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
        let param_count;
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          param_count = _ok._0;
        } else {
          return _bind$3;
        }
        const params = [];
        let _tmp$2 = 0;
        while (true) {
          const _$2 = _tmp$2;
          if (_$2 >>> 0 < param_count >>> 0) {
            const _bind$4 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
            let _tmp$3;
            if (_bind$4.$tag === 1) {
              const _ok = _bind$4;
              _tmp$3 = _ok._0;
            } else {
              return _bind$4;
            }
            _M0MP311moonbitlang4core5array5Array4pushGsE(params, _M0FP36mizchi4wite12plugin_2dapi15val__type__name(_tmp$3));
            _tmp$2 = (_$2 >>> 0) + (1 >>> 0) | 0;
            continue;
          } else {
            break;
          }
        }
        const _bind$4 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
        let result_count;
        if (_bind$4.$tag === 1) {
          const _ok = _bind$4;
          result_count = _ok._0;
        } else {
          return _bind$4;
        }
        const results = [];
        let _tmp$3 = 0;
        while (true) {
          const _$2 = _tmp$3;
          if (_$2 >>> 0 < result_count >>> 0) {
            const _bind$5 = _M0MP36mizchi4wite8optimize6Cursor10read__byte(parser);
            let _tmp$4;
            if (_bind$5.$tag === 1) {
              const _ok = _bind$5;
              _tmp$4 = _ok._0;
            } else {
              return _bind$5;
            }
            _M0MP311moonbitlang4core5array5Array4pushGsE(results, _M0FP36mizchi4wite12plugin_2dapi15val__type__name(_tmp$4));
            _tmp$3 = (_$2 >>> 0) + (1 >>> 0) | 0;
            continue;
          } else {
            break;
          }
        }
        _M0MP311moonbitlang4core5array5Array4pushGRP36mizchi4wite12plugin_2dapi7FuncSigE(out, { params: params, results: results });
        break _L;
      }
      _tmp = (_ >>> 0) + (1 >>> 0) | 0;
      continue;
    } else {
      break;
    }
  }
  return new Result$Ok$8$(out);
}
function _M0FP36mizchi4wite12plugin_2dapi30parse__function__type__indices(payload) {
  const parser = _M0MP36mizchi4wite8optimize6Cursor3new(payload);
  const _bind = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
  let count;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    count = _ok._0;
  } else {
    return _bind;
  }
  const out = [];
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ >>> 0 < count >>> 0) {
      const _bind$2 = _M0MP36mizchi4wite8optimize6Cursor17read__u32__leb128(parser);
      let _tmp$2;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        _tmp$2 = _ok._0;
      } else {
        return _bind$2;
      }
      _M0MP311moonbitlang4core5array5Array4pushGjE(out, _tmp$2);
      _tmp = (_ >>> 0) + (1 >>> 0) | 0;
      continue;
    } else {
      break;
    }
  }
  return new Result$Ok$9$(out);
}
function _M0FP36mizchi4wite12plugin_2dapi19json__string__array(arr) {
  const parts = [];
  const _len = arr.length;
  let _tmp = 0;
  while (true) {
    const _i = _tmp;
    if (_i < _len) {
      const item = arr[_i];
      _M0MP311moonbitlang4core5array5Array4pushGsE(parts, `\"${_M0FP36mizchi4wite12plugin_2dapi20escape__json__string(item)}\"`);
      _tmp = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return `[${_M0MP311moonbitlang4core5array5Array4joinGsE(parts, { str: _M0FP36mizchi4wite12plugin_2dapi35json__string__array_2e_2abind_7c209, start: 0, end: _M0FP36mizchi4wite12plugin_2dapi35json__string__array_2e_2abind_7c209.length })}]`;
}
function _M0FP36mizchi4wite12plugin_2dapi21parse__wasm__metadata(bytes) {
  if (_M0FP36mizchi4wite12plugin_2dapi21is__component__header(bytes)) {
    return "{\"isComponent\":true,\"types\":[],\"imports\":[],\"exports\":[],\"functions\":[]}";
  }
  let sections;
  let _try_err;
  _L: {
    _L$2: {
      const _bind = _M0FP36mizchi4wite8optimize28parse__core__sections__raise(bytes);
      if (_bind.$tag === 1) {
        const _ok = _bind;
        sections = _ok._0;
      } else {
        const _err = _bind;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    return `{\"error\":\"${_M0FP36mizchi4wite12plugin_2dapi20escape__json__string(_M0FP36mizchi4wite5types17error__to__string(_try_err))}\"}`;
  }
  let types = [];
  let imports = [];
  let exports = [];
  let functions = [];
  const _len = sections.length;
  let _tmp = 0;
  while (true) {
    const _i = _tmp;
    if (_i < _len) {
      const section = sections[_i];
      const payload = _M0MP311moonbitlang4core5bytes9BytesView9to__bytes(_M0MP311moonbitlang4core5bytes5Bytes12view_2einner(bytes, section.payload_start, section.section_end));
      const _bind = section.section_id;
      switch (_bind) {
        case 1: {
          let _try_err$2;
          _L$2: {
            _L$3: {
              const _bind$2 = _M0FP36mizchi4wite12plugin_2dapi18parse__func__types(payload);
              let _tmp$2;
              if (_bind$2.$tag === 1) {
                const _ok = _bind$2;
                _tmp$2 = _ok._0;
              } else {
                const _err = _bind$2;
                _try_err$2 = _err._0;
                break _L$3;
              }
              types = _tmp$2;
              break _L$2;
            }
          }
          break;
        }
        case 2: {
          let _try_err$3;
          _L$3: {
            _L$4: {
              const _bind$2 = _M0FP36mizchi4wite12plugin_2dapi20parse__imports__full(payload);
              let _tmp$2;
              if (_bind$2.$tag === 1) {
                const _ok = _bind$2;
                _tmp$2 = _ok._0;
              } else {
                const _err = _bind$2;
                _try_err$3 = _err._0;
                break _L$4;
              }
              imports = _tmp$2;
              break _L$3;
            }
          }
          break;
        }
        case 3: {
          let _try_err$4;
          _L$4: {
            _L$5: {
              const _bind$2 = _M0FP36mizchi4wite12plugin_2dapi30parse__function__type__indices(payload);
              let _tmp$2;
              if (_bind$2.$tag === 1) {
                const _ok = _bind$2;
                _tmp$2 = _ok._0;
              } else {
                const _err = _bind$2;
                _try_err$4 = _err._0;
                break _L$5;
              }
              functions = _tmp$2;
              break _L$4;
            }
          }
          break;
        }
        case 7: {
          let _try_err$5;
          _L$5: {
            _L$6: {
              const _bind$2 = _M0FP36mizchi4wite12plugin_2dapi20parse__exports__full(payload);
              let _tmp$2;
              if (_bind$2.$tag === 1) {
                const _ok = _bind$2;
                _tmp$2 = _ok._0;
              } else {
                const _err = _bind$2;
                _try_err$5 = _err._0;
                break _L$6;
              }
              exports = _tmp$2;
              break _L$5;
            }
          }
          break;
        }
      }
      _tmp = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const out = [];
  _M0MP311moonbitlang4core5array5Array4pushGsE(out, "{\"isComponent\":false");
  const type_parts = [];
  const _arr = types;
  const _len$2 = _arr.length;
  let _tmp$2 = 0;
  while (true) {
    const _i = _tmp$2;
    if (_i < _len$2) {
      const t = _arr[_i];
      _M0MP311moonbitlang4core5array5Array4pushGsE(type_parts, `{\"params\":${_M0FP36mizchi4wite12plugin_2dapi19json__string__array(t.params)},\"results\":${_M0FP36mizchi4wite12plugin_2dapi19json__string__array(t.results)}}`);
      _tmp$2 = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MP311moonbitlang4core5array5Array4pushGsE(out, `,\"types\":[${_M0MP311moonbitlang4core5array5Array4joinGsE(type_parts, { str: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c232, start: 0, end: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c232.length })}]`);
  const import_parts = [];
  const _arr$2 = imports;
  const _len$3 = _arr$2.length;
  let _tmp$3 = 0;
  while (true) {
    const _i = _tmp$3;
    if (_i < _len$3) {
      const imp = _arr$2[_i];
      let s = `{\"module\":\"${_M0FP36mizchi4wite12plugin_2dapi20escape__json__string(imp.mod_name)}\"`;
      s = `${s},\"name\":\"${_M0FP36mizchi4wite12plugin_2dapi20escape__json__string(imp.name)}\"`;
      s = `${s},\"kind\":\"${_M0FP36mizchi4wite12plugin_2dapi18import__kind__name(imp.kind)}\"`;
      const _bind = imp.type_index;
      if (_bind === undefined) {
      } else {
        const _Some = _bind;
        const _idx = _Some;
        s = `${s},\"typeIndex\":${_M0MP311moonbitlang4core4uint4UInt18to__string_2einner(_idx, 10)}`;
      }
      s = `${s}}`;
      _M0MP311moonbitlang4core5array5Array4pushGsE(import_parts, s);
      _tmp$3 = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MP311moonbitlang4core5array5Array4pushGsE(out, `,\"imports\":[${_M0MP311moonbitlang4core5array5Array4joinGsE(import_parts, { str: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c240, start: 0, end: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c240.length })}]`);
  const export_parts = [];
  const _arr$3 = exports;
  const _len$4 = _arr$3.length;
  let _tmp$4 = 0;
  while (true) {
    const _i = _tmp$4;
    if (_i < _len$4) {
      const exp = _arr$3[_i];
      _M0MP311moonbitlang4core5array5Array4pushGsE(export_parts, `{\"name\":\"${_M0FP36mizchi4wite12plugin_2dapi20escape__json__string(exp.name)}\",\"kind\":\"${_M0FP36mizchi4wite12plugin_2dapi18export__kind__name(exp.kind)}\",\"index\":${_M0MP311moonbitlang4core4uint4UInt18to__string_2einner(exp.index, 10)}}`);
      _tmp$4 = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MP311moonbitlang4core5array5Array4pushGsE(out, `,\"exports\":[${_M0MP311moonbitlang4core5array5Array4joinGsE(export_parts, { str: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c243, start: 0, end: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c243.length })}]`);
  const func_parts = [];
  const _arr$4 = functions;
  const _len$5 = _arr$4.length;
  let _tmp$5 = 0;
  while (true) {
    const _i = _tmp$5;
    if (_i < _len$5) {
      const idx = _arr$4[_i];
      _M0MP311moonbitlang4core5array5Array4pushGsE(func_parts, _M0MP311moonbitlang4core4uint4UInt18to__string_2einner(idx, 10));
      _tmp$5 = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MP311moonbitlang4core5array5Array4pushGsE(out, `,\"functions\":[${_M0MP311moonbitlang4core5array5Array4joinGsE(func_parts, { str: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c246, start: 0, end: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c246.length })}]`);
  _M0MP311moonbitlang4core5array5Array4pushGsE(out, "}");
  return _M0MP311moonbitlang4core5array5Array4joinGsE(out, { str: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c247, start: 0, end: _M0FP36mizchi4wite12plugin_2dapi37parse__wasm__metadata_2e_2abind_7c247.length });
}
function _M0FP36mizchi4wite12plugin_2dapi24is__core__module__header(bytes) {
  if (bytes.length >= 8) {
    let _tmp;
    $bound_check(bytes, 0);
    const _p = bytes[0];
    const _p$2 = 0;
    if (_p === _p$2) {
      let _tmp$2;
      $bound_check(bytes, 1);
      const _p$3 = bytes[1];
      const _p$4 = 97;
      if (_p$3 === _p$4) {
        let _tmp$3;
        $bound_check(bytes, 2);
        const _p$5 = bytes[2];
        const _p$6 = 115;
        if (_p$5 === _p$6) {
          let _tmp$4;
          $bound_check(bytes, 3);
          const _p$7 = bytes[3];
          const _p$8 = 109;
          if (_p$7 === _p$8) {
            let _tmp$5;
            $bound_check(bytes, 4);
            const _p$9 = bytes[4];
            const _p$10 = 1;
            if (_p$9 === _p$10) {
              let _tmp$6;
              $bound_check(bytes, 5);
              const _p$11 = bytes[5];
              const _p$12 = 0;
              if (_p$11 === _p$12) {
                let _tmp$7;
                $bound_check(bytes, 6);
                const _p$13 = bytes[6];
                const _p$14 = 0;
                if (_p$13 === _p$14) {
                  $bound_check(bytes, 7);
                  const _p$15 = bytes[7];
                  const _p$16 = 0;
                  _tmp$7 = _p$15 === _p$16;
                } else {
                  _tmp$7 = false;
                }
                _tmp$6 = _tmp$7;
              } else {
                _tmp$6 = false;
              }
              _tmp$5 = _tmp$6;
            } else {
              _tmp$5 = false;
            }
            _tmp$4 = _tmp$5;
          } else {
            _tmp$4 = false;
          }
          _tmp$3 = _tmp$4;
        } else {
          _tmp$3 = false;
        }
        _tmp$2 = _tmp$3;
      } else {
        _tmp$2 = false;
      }
      _tmp = _tmp$2;
    } else {
      _tmp = false;
    }
    return _tmp;
  } else {
    return false;
  }
}
function _M0FP36mizchi4wite12plugin_2dapi28extract__first__core__module(bytes) {
  if (!_M0FP36mizchi4wite12plugin_2dapi21is__component__header(bytes)) {
    return _M0MP311moonbitlang4core5bytes5Bytes3new(0);
  }
  let sections;
  let _try_err;
  _L: {
    _L$2: {
      const _bind = _M0FP36mizchi4wite8optimize33parse__component__sections__raise(bytes);
      if (_bind.$tag === 1) {
        const _ok = _bind;
        sections = _ok._0;
      } else {
        const _err = _bind;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    return _M0MP311moonbitlang4core5bytes5Bytes3new(0);
  }
  const _len = sections.length;
  let _tmp = 0;
  while (true) {
    const _i = _tmp;
    if (_i < _len) {
      const section = sections[_i];
      if (section.section_id === 1) {
        const payload = _M0MP311moonbitlang4core5bytes9BytesView9to__bytes(_M0MP311moonbitlang4core5bytes5Bytes12view_2einner(bytes, section.payload_start, section.section_end));
        if (_M0FP36mizchi4wite12plugin_2dapi24is__core__module__header(payload)) {
          return payload;
        }
      }
      _tmp = _i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MP311moonbitlang4core5bytes5Bytes3new(0);
}
(() => {
})();
export { _M0FP36mizchi4wite12plugin_2dapi21parse__wasm__metadata as parse_wasm_metadata, _M0FP36mizchi4wite12plugin_2dapi28extract__first__core__module as extract_first_core_module }
