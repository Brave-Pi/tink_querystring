package tink.querystring.macros;

import haxe.macro.Context;
import tink.macro.BuildCache;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.typecrawler.Crawler;
import tink.typecrawler.FieldInfo;
import tink.typecrawler.Generator;

using haxe.macro.TypeTools;
using tink.MacroApi;

class GenParser { 
  
  var name:String;
  
  var valueType:Type;
  var resultType:Type;
  var inputType:Type;
  
  var value:ComplexType;
  var result:ComplexType;
  var input:ComplexType;
  
  var pos:Position;
  var _int:Expr;
  var _float:Expr;
  var _string:Expr;
  
  function new(name, rawType:Type, pos) {
    
    this.pos = pos;
    this.name = name;
    //keyType, valueType, 
    
    
    this.resultType = 
      switch rawType.reduce() {
        case TFun([{ t: input }, { t: value }], result):
          
          this.inputType = input;
          this.valueType = value;
          
          result;
          
        case TFun([{ t: value }], result):
          
          this.valueType = value;
          
          result;
          
        case result: 
                    
          result;
      }
      
    this.result = resultType.toComplex();
      
    if (this.value == null) {
      if (this.valueType == null) {
        this.value = macro : tink.url.Portion;
        this.valueType = value.toType(pos).sure();
      }
      else this.value = this.valueType.toComplex();
    }
      
    if (this.input == null) {
      if (this.inputType == null) {
        this.input = macro : tink.querystring.Pairs<$value>;
        this.inputType = input.toType(pos).sure();
      }
      else this.input = this.inputType.toComplex();
    }
        
    this._string = 
      if ((macro ((null:$value):String)).typeof().isSuccess()) 
        prim(macro : String);
      else 
        pos.error('${value.toString()} should be compatible with String');
        
    this._int =
      if ((macro ((null:$value):Int)).typeof().isSuccess())
        prim(macro : Int);
      else
        macro this.parseInt($ { prim(macro : String) } );
        
    this._float =
      if ((macro ((null:$value):Float)).typeof().isSuccess())
        prim(macro : Float);
      else
        macro this.parseFloat(${prim(macro : String)});
  }
  
  public function get() {
    var crawl = Crawler.crawl(resultType, pos, this);
    
    var ret = macro class $name extends tink.querystring.Parser.ParserBase<$input, $value, $result> {
      
      function getName(p):String return p.name;
      function getValue(p):$value return p.value;
      
      override public function parse(input:$input) {
        var prefix = '';
        this.init(input, getName, getValue);
        return ${crawl.expr};
      }
      
    }
    
    ret.fields = ret.fields.concat(crawl.fields);
    
    return ret;    
  }
  
  //static function decompose(type:Type) 
    //return switch type.reduce() {
      //case TFun([input], result):
        //
        //{ input: input, result: result };
        //
      //case TFun(v, _):
        //
        //Context.currentPos().error('Can define input and result type, but not more');
        //
      //case v:
        //
        //{ input: (macro : tink.querystring.Pairs<tink.url.Portion>).toType().sure(), result: v };
    //}

  static function buildNew(ctx:BuildContext) 
    return new GenParser(ctx.name, ctx.type, ctx.pos).get();    
  
  static public function build() {
    return BuildCache.getType('tink.querystring.Parser', buildNew);
    //return switch Context.getCallArguments() {
      //case null:
        //decompose()
      //case v:
        //
    //}
  }
    
  public function args():Array<String> 
    return ['prefix'];
    
  public function nullable(e:Expr):Expr 
    return 
      macro 
        if (exists[prefix]) $e;
        else null;
  
  function prim(wanted:ComplexType) 
    return 
      macro 
        if (exists[prefix]) ((params[prefix]:$value):$wanted);
        else missing(prefix); 
    
  public function string():Expr 
    return _string;
    
  public function float():Expr
    return _float;
  
  public function int():Expr 
    return _int;
    
  public function dyn(e:Expr, ct:ComplexType):Expr {
    return throw "not implemented";
  }
  public function dynAccess(e:Expr):Expr {
    return throw "not implemented";
  }
  public function bool():Expr {
    return macro (${string()}) == 'true';
  }
  public function date():Expr {
    return throw "not implemented";
  }
  public function bytes():Expr {
    return throw "not implemented";
  }
  
  public function anon(fields:Array<FieldInfo>, ct:ComplexType):Function {
    var ret = [];
    for (f in fields)
      ret.push( { 
        field: f.name, 
        expr: macro {
          var prefix = switch prefix {
            case '': $v{f.name};
            case v: v + $v{ '.' + f.name};
          }
          ${f.expr};
        } 
      });
    return (macro function (prefix:String):$ct {
      return ${EObjectDecl(ret).at()};
    }).getFunction().sure();
  }
  
  public function array(e:Expr):Expr {
    return macro {
      
      var counter = 0,
          ret = [];
      
      while (true) {
        var prefix = prefix + '[' + counter + ']';
        
        if (exists[prefix]) {
          ret.push($e);
          counter++;
        }
        else break;
      }
      
      ret;
    }
  }
  public function map(k:Expr, v:Expr):Expr {
    return throw "not implemented";
  }
  public function enm(constructors:Array<EnumConstructor>, ct:ComplexType, pos:Position, gen:GenType):Expr {
    return throw "not implemented";
  }
  public function rescue(t:Type, pos:Position, gen:GenType):Option<Expr> {
    return Some(prim(t.toComplex()));
  }
  public function reject(t:Type):String {
    return 'Cannot parse ${t.toString()}';
  }    
}