( function _Execution_s_()
{

'use strict';

let System, ChildProcess, StripAnsi, WindowsKill, WindowsProcessTree;
let _global = _global_;
let _ = _global_.wTools;
let Self = _.process = _.process || Object.create( null );

_.assert( !!_realGlobal_ );

// --
// starter
// --

/* Return values of routine start for each combination of options sync and deasync:

  Single process
  | Combination      | Options map | Consequence |
  | ---------------- | ----------- | ----------- |
  | sync:0 deasync:0 | +           | +           |
  | sync:1 deasync:1 | +           | -           |
  | sync:0 deasync:1 | +           | +           |
  | sync:1 deasync:0 | +           | -           |

  Multiple processes
  | Combination      | Array of maps of options | Single options map | Consequence |
  | ---------------- | ------------------------ | ------------------ | ----------- |
  | sync:0 deasync:0 | +                        | -                  | +           |
  | sync:1 deasync:1 | +                        | -                  | -           |
  | sync:0 deasync:1 | +                        | -                  | +           |
  | sync:1 deasync:0 | -                        | +                  | -           |
*/


//

function startCommon_pre( routine, args )
{
  let o;

  if( _.strIs( args[ 0 ] ) || _.arrayIs( args[ 0 ] ) )
  o = { execPath : args[ 0 ] };
  else
  o = args[ 0 ];

  o = _.routineOptions( routine, o );

  _.assert( arguments.length === 2 );
  _.assert( args.length === 1, 'Expects single argument' );
  _.assert( _.longHas( [ 'fork', 'spawn', 'shell' ], o.mode ), `Supports mode::[ 'fork', 'spawn', 'shell' ]. Unknown mode ${o.mode}` );
  _.assert( !!o.args || !!o.execPath, 'Expects {-args-} either {-execPath-}' )
  _.assert( o.args === null || _.arrayIs( o.args ) || _.strIs( o.args ) );
  _.assert
  (
    o.timeOut === null || _.numberIs( o.timeOut ),
    `Expects null or number {-o.timeOut-}, but got ${_.strType( o.timeOut )}`
  );
  _.assert( _.longHas( [ 'instant' ], o.when ) || _.objectIs( o.when ), `Unsupported starting mode: ${o.when}` );
  _.assert( o.when !== 'afterdeath', `Starting mode:'afterdeath' is moved to separate routine _.process.startAfterDeath` );
  _.assert
  (
    !o.detaching || !_.longHas( _.arrayAs( o.stdio ), 'inherit' ),
    `Unsupported stdio: ${o.stdio} for process detaching. Parent will wait for child process.` /* xxx : check */
  );
  _.assert( !o.detaching || _.longHas( [ 'fork', 'spawn', 'shell' ], o.mode ), `Unsupported mode: ${o.mode} for process detaching` );
  _.assert( o.conStart === null || _.routineIs( o.conStart ) );
  _.assert( o.conTerminate === null || _.routineIs( o.conTerminate ) );
  _.assert( o.conDisconnect === null || _.routineIs( o.conDisconnect ) );
  _.assert( o.ready === null || _.routineIs( o.ready ) );
  _.assert( o.mode !== 'fork' || !o.sync || o.deasync, 'Mode::fork is available only if either sync:0 or deasync:1' );

  if( o.outputDecorating === null )
  o.outputDecorating = 0;
  if( o.outputDecoratingStdout === null )
  o.outputDecoratingStdout = o.outputDecorating;
  if( o.outputDecoratingStderr === null )
  o.outputDecoratingStderr = o.outputDecorating;
  _.assert( _.boolLike( o.outputDecorating ) );
  _.assert( _.boolLike( o.outputDecoratingStdout ) );
  _.assert( _.boolLike( o.outputDecoratingStderr ) );

  if( !_.numberIs( o.verbosity ) )
  o.verbosity = o.verbosity ? 1 : 0;
  if( o.verbosity < 0 )
  o.verbosity = 0;
  if( o.outputPiping === null )
  {
    if( o.stdio === 'pipe' || o.stdio[ 1 ] === 'pipe' )
    o.outputPiping = o.verbosity >= 2;
  }
  o.outputPiping = !!o.outputPiping;
  _.assert( _.numberIs( o.verbosity ) );
  _.assert( _.boolLike( o.outputPiping ) );

  if( o.outputAdditive === null )
  o.outputAdditive = true;
  o.outputAdditive = !!o.outputAdditive;
  _.assert( _.boolLike( o.outputAdditive ) );

  if( o.ipc === null )
  o.ipc = o.mode === 'fork' ? true : false;
  _.assert( _.boolLike( o.ipc ) );

  if( _.strIs( o.interpreterArgs ) )
  o.interpreterArgs = _.strSplitNonPreserving({ src : o.interpreterArgs });
  _.assert( o.interpreterArgs === null || _.arrayIs( o.interpreterArgs ) );

  return o;
}

//

function startSingle_pre( routine, args )
{
  let o = startCommon_pre( routine, args );

  _.assert( arguments.length === 2 );

  _.assert
  (
    o.execPath === null || _.strIs( o.execPath )
    , `Expects string or strings {-o.execPath-}, but got ${_.strType( o.execPath )}`
  );

  _.assert
  (
    o.currentPath === null || _.strIs( o.currentPath )
    , `Expects string or strings {-o.currentPath-}, but got ${_.strType( o.currentPath )}`
  );

  return o;
}

//

function startSingle_body( o )
{

  /* subroutines index :

  form1,
  form2,
  form3,
  run1,
  run2,
  run3,
  runFork,
  runSpawn,
  runShell,
  end1,
  end2,

  handleClose,
  handleExit,
  handleError,
  handleDisconnect,
  disconnect,
  timeOutForm,
  pipe,
  inputMirror,
  execPathParse,
  argsUnqoute,
  argsJoin,
  argEscape,
  optionsForSpawn,
  optionsForFork,
  execPathForFork,
  handleProcedureTerminationBegin,
  exitCodeSet,
  infoGet,
  handleStderr,
  handleStdout,
  log,

*/

  _.assert( arguments.length === 1, 'Expects single argument' );

  let stderrOutput = '';
  let decoratedOutput = '';
  let decoratedErrorOutput = '';
  let execArgs, readyCallback;

  form1();

  _.assert( !_.arrayIs( o.execPath ) && !_.arrayIs( o.currentPath ) );

  form2();

  return run1();

  /* */

  function form1()
  {

    if( o.ready === null )
    {
      o.ready = new _.Consequence().take( null );
    }
    else if( !_.consequenceIs( o.ready ) )
    {
      readyCallback = o.ready;
      _.assert( _.routineIs( readyCallback ) );
      o.ready = new _.Consequence().take( null );
    }

    _.assert( !_.consequenceIs( o.ready ) || o.ready.resourcesCount() <= 1 );

    o.logger = o.logger || _global.logger;

  }

  /* */

  function form2()
  {

    /* procedure */

    if( o.procedure === null || _.boolLikeTrue( o.procedure ) )
    o.stack = _.Procedure.Stack( o.stack, 3 );

    /* */

    if( o.conStart === null )
    {
      o.conStart = new _.Consequence();
    }
    else if( !_.consequenceIs( o.conStart ) )
    {
      o.conStart = new _.Consequence().finally( o.conStart );
    }

    if( o.conTerminate === null )
    {
      o.conTerminate = new _.Consequence();
    }
    else if( !_.consequenceIs( o.conTerminate ) )
    {
      o.conTerminate = new _.Consequence({ _procedure : false }).finally( o.conTerminate );
    }

    if( o.conDisconnect === null )
    {
      o.conDisconnect = new _.Consequence();
    }
    else if( !_.consequenceIs( o.conDisconnect ) )
    {
      o.conDisconnect = new _.Consequence({ _procedure : false }).finally( o.conDisconnect );
    }

    _.assert( o.conStart !== o.conTerminate );
    _.assert( o.conStart !== o.conDisconnect );
    _.assert( o.conTerminate !== o.conDisconnect );
    _.assert( o.ready !== o.conStart && o.ready !== o.conDisconnect && o.ready !== o.conTerminate );
    _.assert( o.conStart.resourcesCount() === 0 );
    _.assert( o.conDisconnect.resourcesCount() === 0 );
    _.assert( o.conTerminate.resourcesCount() === 0 );

    /* */

    // if( o.outputDecorating === null )
    // o.outputDecorating = 0;
    // if( o.outputDecoratingStdout === null )
    // o.outputDecoratingStdout = o.outputDecorating;
    // if( o.outputDecoratingStderr === null )
    // o.outputDecoratingStderr = o.outputDecorating;

    /* ipc */

    _.assert( _.boolLike( o.ipc ) );

    // if( o.ipc === null )
    // o.ipc = o.mode === 'fork' ? 1 : 0;

    if( _.strIs( o.stdio ) )
    o.stdio = _.dup( o.stdio, 3 );
    if( o.ipc )
    {
      // yyy
      // if( _.strIs( o.stdio ) )
      // o.stdio = _.dup( o.stdio, 3 );
      if( !_.longHas( o.stdio, 'ipc' ) )
      o.stdio.push( 'ipc' );
    }

    _.assert( !o.ipc || _.longHas( [ 'fork', 'spawn' ], o.mode ), `Mode::${o.mode} doesn't support inter process communication.` );
    _.assert( o.mode !== 'fork' || !!o.ipc, `In mode::fork option::ipc must be true. Such subprocess can not have no ipc.` );

    /* */

    if( !_.strIs( o.when ) )
    {
      if( Config.debug )
      {
        let keys = _.mapKeys( o.when );
        _.assert( _.mapIs( o.when ) );
        _.assert( keys.length === 1 && _.longHas( [ 'time', 'delay' ], keys[ 0 ] ) );
        _.assert( _.numberIs( o.when.delay ) || _.numberIs( o.when.time ) )
      }
      if( o.when.time !== undefined )
      o.when.delay = Math.max( 0, o.when.time - _.time.now() );
      _.assert
      (
        o.when.delay >= 0,
        `Wrong value of {-o.when.delay } or {-o.when.time-}. Starting delay should be >= 0, current : ${o.when.delay}`
      );
    }

    /* */

    _.assert( _.boolLike( o.outputDecorating ) );
    _.assert( _.boolLike( o.outputDecoratingStdout ) );
    _.assert( _.boolLike( o.outputDecoratingStderr ) );
    _.assert( _.boolLike( o.outputCollecting ) );

    o.disconnect = disconnect;
    o.state = 'initial'; /* `initial`, `starting`, `started`, `terminating`, `terminated`, `disconnected` */
    o.exitReason = null;
    o.exitCode = null;
    o.exitSignal = null;
    o.error = null;
    o.process = null;
    o.procedure = null;
    o.fullExecPath = null;
    o.output = o.outputCollecting ? '' : null;
    o.ended = false;
    o.handleProcedureTerminationBegin = false;

    Object.preventExtensions( o );
  }

  /* */

  function form3()
  {

    if( _.arrayIs( o.args ) )
    o.args = o.args.slice();
    o.args = _.arrayAs( o.args );

    if( _.strIs( o.execPath ) )
    {
      o.fullExecPath = o.execPath;
      execArgs = execPathParse( o.execPath );
      if( o.mode !== 'shell' )
      execArgs = argsUnqoute( execArgs );
      if( execArgs.length )
      o.execPath = execArgs.shift();
      else
      o.execPath = null;
    }

    if( o.execPath === null )
    {
      _.assert( o.args.length, 'Expects {-args-} to have at least one argument if {-execPath-} is not defined' );

      o.execPath = o.args.shift();
      o.fullExecPath = o.execPath;

      let begin = _.strBeginOf( o.execPath, [ '"', `'`, '`' ] );
      let end = _.strEndOf( o.execPath, [ '"', `'`, '`' ] );

      if( begin && begin === end )
      o.execPath = _.strInsideOf( o.execPath, begin, end );
    }

    if( execArgs && execArgs.length )
    o.args = _.arrayPrependArray( o.args || [], execArgs );

    _.assert( o.interpreterArgs === null || _.arrayIs( o.interpreterArgs ) );
    // if( _.strIs( o.interpreterArgs ) )
    // o.interpreterArgs = _.strSplitNonPreserving({ src : o.interpreterArgs });

    // if( o.outputAdditive === null )
    // o.outputAdditive = true;
    // o.outputAdditive = !!o.outputAdditive;
    _.assert( _.boolLike( o.outputAdditive ) );

    o.currentPath = _.path.resolve( o.currentPath || '.' );

    /* verbosity */

    // if( !_.numberIs( o.verbosity ) )
    // o.verbosity = o.verbosity ? 1 : 0;
    // if( o.verbosity < 0 )
    // o.verbosity = 0;
    // if( o.outputPiping === null )
    // {
    //   if( o.stdio === 'pipe' || o.stdio[ 1 ] === 'pipe' )
    //   o.outputPiping = o.verbosity >= 2;
    // }
    _.assert( _.numberIs( o.verbosity ) );
    _.assert( _.boolLike( o.outputPiping ) );

    // if( o.outputCollecting && !o.output )
    // o.output = ''; /* xxx : test for multiple run? to which o-map does it collect output? */

    /* stdio compatibility check */
    if( Config.debug )
    if( o.outputPiping || o.outputCollecting )
    _.assert( o.stdio === 'pipe' || o.stdio[ 1 ] === 'pipe' || o.stdio[ 2 ] === 'pipe', '"stdout" is not available to collect output or pipe it. Set stdout/stderr channel(s) or option::stdio to "pipe", please' );

    /* passingThrough */

    if( o.passingThrough )
    {
      let argumentsManual = process.argv.slice( 2 );
      if( argumentsManual.length )
      o.args = _.arrayAppendArray( o.args || [], argumentsManual );
    }

    /* dependencies */

    if( !ChildProcess )
    ChildProcess = require( 'child_process' );

    if( o.outputGraying )
    if( !StripAnsi )
    StripAnsi = require( 'strip-ansi' );

    if( !o.outputDecorating && typeof module !== 'undefined' )
    try
    {
      _.include( 'wColor' );
    }
    catch( err )
    {
      if( o.verbosity >= 2 )
      log( _.errOnce( err ), 1 );
    }

    /* handler of event terminationBegin */

    if( o.detaching )
    {
      _.procedure.on( 'terminationBegin', handleProcedureTerminationBegin );
      o.handleProcedureTerminationBegin = handleProcedureTerminationBegin;
    }

  }

  /* */

  function run1()
  {

    if( o.sync && !o.deasync )
    {
      try
      {

        o.ready.deasync();
        let arg = o.ready.sync();
        o.ready.give( 1 );

        if( readyCallback )
        o.ready.finally( readyCallback );

        if( o.when.delay )
        _.time.sleep( o.when.delay );

        run2();

      }
      catch( err )
      {
        debugger; /* qqq for Yevhen : is covered? */
        end2( err, o.conTerminate );
      }
      _.assert( o.state === 'terminated' || o.state === 'disconnected' );
      end2( undefined, o.conTerminate );
      return o;
    }
    else
    {
      if( o.when.delay )
      o.ready.timeOut( o.when.delay );

      o.ready.thenGive( run2 );

      if( readyCallback )
      debugger;
      if( readyCallback )
      o.ready.finally( readyCallback );

      return end1();
    }

  }

  /* */

  function run2()
  {

    _.assert( o.state === 'initial' );

    try
    {
      form3();
      run3();
      timeOutForm();
      pipe();
      if( o.dry )
      {
        /* qqq for Yevhen : make sure option dry is covered good enough */
        _.assert( o.state === 'started' );
        o.state = 'terminated';
        end2( undefined, o.conTerminate );
      }
    }
    catch( err )
    {
      debugger
      handleError( err );
    }

  }

  /* */

  function run3()
  {
    o.state = 'starting';

    if( Config.debug )
    _.assert
    (
      _.fileProvider.isDir( o.currentPath ),
      () => `Current path ( ${o.currentPath} ) doesn\'t exist or it\'s not a directory.\n> ${o.fullExecPath}`
    );

    // let execPath = o.execPath;
    // let args = o.args; /* yyy zzz : remove? */
    // /* let args = o.args.slice(); */

    // if( process.platform === 'win32' )
    // {
    //   execPath = _.path.nativizeTolerant( execPath );
    // }

    if( o.mode === 'fork')
    {
      runFork();
    }
    else if( o.mode === 'spawn' )
    {
      runSpawn();
    }
    else if( o.mode === 'shell' )
    {
      runShell();
    }
    else _.assert( 0, 'Unknown mode', _.strQuote( o.mode ), 'to start process at path', _.strQuote( o.currentPath ) );

    /* procedure */

    if( !o.dry ) /* xxx : remove if? */
    if( o.procedure === null || _.boolLikeTrue( o.procedure ) )
    {
      if( Config.debug )
      {
        let result = _.procedure.find( 'PID:' + o.process.pid );
        _.assert( result.length === 0, `No procedure expected for child process with pid:${o.process.pid}` );
      }
      o.procedure = _.procedure.begin({ _name : 'PID:' + o.process.pid, _object : o.process, _stack : o.stack });
    }

    /* state */

    o.state = 'started';
    o.conStart.take( o );
  }

  /* */

  function runFork()
  {
    let execPath = o.execPath;
    // let args = o.args; /* yyy zzz : remove? */
    // let args = o.args.slice();

    let o2 = optionsForFork();
    execPath = execPathForFork( execPath );

    o.fullExecPath = _.strConcat( _.arrayAppendArray( [ execPath ], o.args ) );
    inputMirror();

    if( o.dry )
    return;

    o.process = ChildProcess.fork( execPath, o.args, o2 );

  }

  /* */

  function runSpawn()
  {
    let execPath = o.execPath;
    // let args = o.args; /* yyy zzz : remove? */
    // let args = o.args.slice();

    let o2 = optionsForSpawn();

    o.fullExecPath = _.strConcat( _.arrayAppendArray( [ execPath ], o.args ) );
    inputMirror();

    if( o.dry )
    return;

    if( o.sync && !o.deasync )
    o.process = ChildProcess.spawnSync( execPath, o.args, o2 );
    else
    o.process = ChildProcess.spawn( execPath, o.args, o2 );

  }

  /* */

  function runShell()
  {
    let execPath = o.execPath;
    // let args = o.args; /* yyy zzz : remove? */
    // let args = o.args.slice();

    let shellPath = process.platform === 'win32' ? 'cmd' : 'sh';
    let arg1 = process.platform === 'win32' ? '/c' : '-c';
    let arg2 = execPath;
    let o2 = optionsForSpawn();

    /*

    windowsVerbatimArguments allows to have arguments with space(s) in shell on Windows
    Following calls will not work as expected( argument will be splitted by space ), if windowsVerbatimArguments is disabled:

    _.process.start( 'node path/to/script.js "path with space"' );
    _.process.start({ execPath : 'node path/to/script.js', args : [ "path with space" ] });

   */

    o2.windowsVerbatimArguments = true;

    if( o.args.length )
    arg2 = arg2 + ' ' + argsJoin( o.args.slice() );

    o.fullExecPath = arg2;
    inputMirror();

    if( o.dry )
    return;

    if( o.sync && !o.deasync )
    o.process = ChildProcess.spawnSync( shellPath, [ arg1, arg2 ], o2 );
    else
    o.process = ChildProcess.spawn( shellPath, [ arg1, arg2 ], o2 );
  }

  /* */

  function timeOutForm()
  {

    if( o.timeOut && !o.dry )
    if( !o.sync || o.deasync )
    _.time.begin( o.timeOut, () =>
    {
      if( o.state === 'terminated' || o.error )
      return;
      o.exitReason = 'time';
      _.process.terminate({ pnd : o.process, withChildren : 1 });
    });

  }

  /* */

  function end1()
  {
    if( o.deasync )
    {
      o.ready.deasync();
      if( o.sync )
      return o.ready.sync();
    }
    return o.ready;
  }

  /* */

  function end2( err, consequence )
  {

    // if( !_.primitiveIs( o.procedure ) ) /* yyy */
    if( o.procedure )
    if( o.procedure.isAlive() )
    o.procedure.end();

    if( o.handleProcedureTerminationBegin )
    {
      _.procedure.off( 'terminationBegin', handleProcedureTerminationBegin );
      o.handleProcedureTerminationBegin = false;
    }

    if( !o.outputAdditive )
    {
      if( decoratedOutput )
      o.logger.log( decoratedOutput );
      if( decoratedErrorOutput )
      o.logger.error( decoratedErrorOutput );
    }

    if( err )
    o.error = o.error || err;

    if( Config.debug )
    try
    {
      _.assert( o.state === 'terminated' || o.state === 'disconnected' || !!o.error );
      _.assert( o.ended === false );
    }
    catch( err2 )
    {
      err = err || err2;
    }

    o.ended = true;
    Object.freeze( o );

    if( err )
    {
      debugger;
      consequence.error( err );
      o.ready.error( err );
      if( o.sync && !o.deasync )
      throw _.err( err );
    }
    else
    {
      consequence.take( o );
      o.ready.take( o );
    }

    return o;
  }

  /* */

  function handleClose( exitCode, exitSignal )
  {
    /*
    console.log( 'handleClose', _.process.realMainFile(), o.ended, ... arguments ); debugger;
    */

    if( o.ended )
    return;

    o.state = 'terminated';

    exitCodeSet( exitCode );
    o.exitSignal = exitSignal;
    if( o.process && o.process.signalCode === undefined )
    o.process.signalCode = exitSignal;

    if( exitSignal )
    o.exitReason = 'signal';
    else if( exitCode )
    o.exitReason = 'code';
    else
    o.exitReason = 'normal';

    if( o.verbosity >= 5 )
    {
      log( ` < Process returned error code ${exitCode}` ); /* qqq for Yevhen : is covered? | aaa : Yes */
      if( exitCode )
      log( infoGet() ); /* qqq for Yevhen : is covered? | aaa : Yes */
    }

    if( ( exitSignal || exitCode !== 0 ) && o.throwingExitCode )
    {
      if( _.numberIs( exitCode ) )
      o.error = _._err({ args : [ 'Process returned exit code', exitCode, '\n', infoGet() ], reason : 'exit code' });
      else if( o.reason === 'time' )
      o.error = _._err({ args : [ 'Process timed out, killed by exit signal', exitSignal, '\n', infoGet() ], reason : 'time out' });
      else
      o.error = _._err({ args : [ 'Process was killed by exit signal', exitSignal, '\n', infoGet() ], reason : 'exit signal' });

      if( o.briefExitCode )
      o.error = _.errBrief( o.error );

      if( o.sync && !o.deasync )
      {
        throw o.error;
      }
      else
      {
        end2( o.error, o.conTerminate );
      }
    }
    else if( !o.sync || o.deasync )
    {
      end2( undefined, o.conTerminate );
    }

  }

  /* */

  function handleExit( a, b, c )
  {
    /*
    console.log( 'handleExit', _.process.realMainFile(), o.ended, ... arguments ); debugger;
    */
  }

  /* */

  function handleError( err )
  {
    err = _.err
    (
      err
      , `\nError starting the process`
      , `\n    Exec path : ${o.fullExecPath || o.execPath}`
      , `\n    Current path : ${o.currentPath}`
      // , `\n\n`
      // , err
    );

    if( o.ended )
    {
      debugger;
      throw err;
    }

    exitCodeSet( -1 );

    o.exitReason = 'error';
    o.error = err;
    if( o.verbosity )
    log( _.errOnce( o.error ), 1 );
    debugger;

    if( o.sync && !o.deasync )
    {
      throw o.error;
    }
    else
    {
      end2( o.error, o.conTerminate );
    }
  }

  /* */

  function handleDisconnect( arg )
  {
    /*
    console.log( 'handleDisconnect', _.process.realMainFile(), o.ended ); debugger;
    */

    /*
    event "disconnect" may come just before event "close"
    so need to give a chance to event "close" to come first
    */

    /*
    if( !o.ended )
    _.time.begin( 1000, () =>
    {
      if( !o.ended )
      {
        debugger;
        o.state = 'disconnected';
        o.conDisconnect.take( this );
        end2( undefined, o );
        throw _.err( 'not tested' );
      }
    });
    */

    /* bad solution
    subprocess waits what does not let emit event "close" in parent process
    */

  }

  /* */

  function disconnect()
  {
    /*
    console.log( 'disconnect', _.process.realMainFile(), this.ended ); debugger;
    */

    _.assert( !!this.process, 'Process is not started. Cant disconnect.' );

    /*
    close event will not be called for regular/detached process
    */

    /*
    if( this.process.stdin )
    this.process.stdin.destroy();
    */
    if( this.process.stdin )
    this.process.stdin.end(); /* yyy */
    if( this.process.stdout )
    this.process.stdout.destroy();
    if( this.process.stderr )
    this.process.stderr.destroy();

    if( this.process.disconnect )
    if( this.process.connected )
    this.process.disconnect();

    this.process.unref();

    if( this.procedure )
    if( this.procedure.isAlive() )
    this.procedure.end();

    if( !this.ended )
    {
      this.state = 'disconnected';
      end2( undefined, o.conDisconnect );
    }

    return true;
  }

  /* */

  function pipe()
  {

    if( o.dry )
    return;

    if( o.outputPiping || o.outputCollecting )
    _.assert( !!o.process.stdout || !!o.process.stderr, 'stdout is not available to collect output or pipe it. Set option::stdio to "pipe"' );

    /* piping out channel */

    if( o.outputPiping || o.outputCollecting )
    if( o.process.stdout )
    if( o.sync && !o.deasync )
    handleStdout( o.process.stdout );
    else
    o.process.stdout.on( 'data', handleStdout );

    /* piping error channel */

    /* there is no if here because algorithm should collect error output in stderrOutput */
    if( o.process.stderr )
    if( o.sync && !o.deasync )
    handleStderr( o.process.stderr );
    else
    o.process.stderr.on( 'data', handleStderr );

    /* handling */

    if( o.sync && !o.deasync )
    {
      if( o.process.error )
      handleError( o.process.error );
      else
      handleClose( o.process.status, o.process.signal );
    }
    else
    {
      o.process.on( 'error', handleError );
      o.process.on( 'close', handleClose );
      o.process.on( 'exit', handleExit );
      o.process.on( 'disconnect', handleDisconnect );
    }

  }

  /* */

  function inputMirror()
  {
    /* logger */
    try
    {

      if( o.verbosity >= 3 )
      {
        let output = '   at ';
        if( !o.outputDecorating )
        output = _.ct.format( output, { fg : 'bright white' } ) + _.ct.format( o.currentPath, 'path' );
        else
        output = output + o.currentPath
        log( output );
      }

      if( o.verbosity && o.inputMirroring )
      {
        let prefix = ' > ';
        if( !o.outputDecorating )
        prefix = _.ct.format( prefix, { fg : 'bright white' } );
        log( prefix + o.fullExecPath );
      }

    }
    catch( err )
    {
      debugger;
      log( _.errOnce( err ), 1 );
    }
  }

  /* */

  function execPathParse( src )
  {
    let strOptions =
    {
      src,
      delimeter : [ ' ' ],
      quoting : 1,
      quotingPrefixes : [ '"', `'`, '`' ],
      quotingPostfixes : [ '"', `'`, '`' ],
      preservingEmpty : 0,
      preservingQuoting : 1,
      stripping : 1
    }
    let args = _.strSplit( strOptions );

    let quotes = [ '"', `'`, '`' ];
    for( let i = 0; i < args.length; i++ )
    {
      let begin = _.strBeginOf( args[ i ], quotes );
      let end = _.strEndOf( args[ i ], quotes );

      if( begin && end )
      if( begin === end )
      continue;

      if( _.longHas( quotes, args[ i ] ) )
      continue;

      let r = _.strQuoteAnalyze
      ({
        src : args[ i ],
        quote : strOptions.quotingPrefixes
      });

      quotes.forEach( ( quote ) =>
      {
        let found = _.strFindAll( args[ i ], quote );

        if( found.length % 2 === 0 )
        return;

        for( let k = 0; k < found.length; k += 1 )
        {
          let pos = found[ k ].charsRangeLeft[ 0 ];

          for( let j = 0; j < r.ranges.length; j += 2 )
          if( pos >= r.ranges[ j ] && pos <= r.ranges[ j + 1 ] )
          break;
          throw _.err( `Arguments string in execPath: ${src} has not closed quoting in argument: ${args[ i ]}` );
        }
      })
    }

    return args;
  }

  /* */

  function argsUnqoute( args )
  {
    let quotes = [ '"', `'`, '`' ];

    for( let i = 0; i < args.length; i++ )
    {
      let begin = _.strBeginOf( args[ i ], quotes );
      let end = _.strEndOf( args[ i ], quotes );
      if( begin )
      if( begin && begin === end )
      args[ i ] = _.strInsideOf( args[ i ], begin, end );
    }

    return args;
  }

  /* */

  function argsJoin( args )
  {
    if( !execArgs && !o.passingThrough )
    return args.join( ' ' );

    let i;

    if( execArgs )
    i = execArgs.length;
    else
    i = args.length - ( process.argv.length - 2 );

    for( ; i < args.length; i++ )
    {
      let quotesToEscape = process.platform === 'win32' ? [ '"' ] : [ '"', '`' ]
      _.each( quotesToEscape, ( quote ) =>
      {
        args[ i ] = argEscape( args[ i ], quote );
      })
      args[ i ] = _.strQuote( args[ i ] );
    }

    return args.join( ' ' );
  }

  /* */

  function argEscape( arg, quote )
  {
    return _.strReplaceAll( arg, quote, ( match, it ) =>
    {
      if( it.input[ it.charsRangeLeft[ 0 ] - 1 ] === '\\' )
      return match;
      return '\\' + match;
    });
  }

  /* */

  function optionsForSpawn()
  {
    let o2 = Object.create( null );
    if( o.stdio )
    o2.stdio = o.stdio;
    o2.detached = !!o.detaching;
    if( o.env )
    o2.env = o.env;
    if( o.currentPath )
    o2.cwd = _.path.nativize( o.currentPath );
    if( o.timeOut && o.sync )
    o2.timeout = o.timeOut;
    o2.windowsHide = !!o.windowHiding;
    return o2;
  }

  /* */

  function optionsForFork()
  {
    let interpreterArgs = o.interpreterArgs || process.execArgv;
    let o2 =
    {
      detached : !!o.detaching,
      env : o.env,
      stdio : o.stdio,
      execArgv : interpreterArgs,
    }
    if( o.currentPath )
    o2.cwd = _.path.nativize( o.currentPath );
    return o2;
  }

  /* */

  function execPathForFork( execPath )
  {
    let quotes = [ '"', `'`, '`' ];
    let begin = _.strBeginOf( execPath, quotes );
    if( begin )
    execPath = _.strInsideOf( execPath, begin, begin );
    return execPath;
  }

  /* */

  function handleProcedureTerminationBegin()
  {
    o.disconnect();
  }

  /* */

  function exitCodeSet( exitCode )
  {
    /*
    console.log( _.process.realMainFile(), 'exitCodeSet', exitCode );
    */
    if( o.exitCode )
    return;
    o.exitCode = exitCode;
    if( o.process && o.process.exitCode === undefined )
    o.process.exitCode = exitCode;
    exitCode = _.numberIs( exitCode ) ? exitCode : -1;
    if( o.applyingExitCode )
    _.process.exitCode( exitCode );
  }

  /* */

  function infoGet()
  {
    let result = '';
    result += `Launched as ${_.strQuote( o.fullExecPath )} \n`;
    result += `Launched at ${_.strQuote( o.currentPath )} \n`;
    if( stderrOutput.length )
    result += `\n -> Stderr\n -  ${_.strLinesIndentation( stderrOutput, ' -  ' )} '\n -< Stderr`;
    return result;
  }

  /* */

  function handleStderr( data )
  {

    if( _.bufferAnyIs( data ) )
    data = _.bufferToStr( data );
    if( o.outputGraying )
    data = StripAnsi( data );

    stderrOutput += data;

    if( o.outputCollecting )
    o.output += data;

    if( !o.outputPiping )
    return;

    data = _.strRemoveEnd( data, '\n' );

    if( o.outputPrefixing )
    data = 'stderr :\n' + '  ' + _.strLinesIndentation( data, '  ' );

    if( _.color && !o.outputDecorating && !o.outputDecoratingStderr )
    data = _.ct.format( data, 'pipe.negative' );

    log( data, 1 );
  }

  /* */

  function handleStdout( data )
  {

    if( _.bufferAnyIs( data ) )
    data = _.bufferToStr( data );
    if( o.outputGraying )
    data = StripAnsi( data );

    if( o.outputCollecting )
    o.output += data;

    if( !o.outputPiping )
    return;

    data = _.strRemoveEnd( data, '\n' );

    if( o.outputPrefixing )
    data = 'stdout :\n' + '  ' + _.strLinesIndentation( data, '  ' );

    if( _.color && !o.outputDecorating && !o.outputDecoratingStdout )
    data = _.ct.format( data, 'pipe.neutral' );

    log( data );
  }

  /* */

  function log( msg, isError )
  {

    if( msg === undefined )
    return;

    if( o.outputAdditive )
    {
      if( isError )
      o.logger.error( msg );
      else
      o.logger.log( msg );
    }
    else
    {
      decoratedOutput += msg + '\n';
      if( isError )
      decoratedErrorOutput += msg + '\n';
    }

  }

  /* */

}

startSingle_body.defaults =
{

  execPath : null,
  currentPath : null,
  args : null,
  interpreterArgs : null,

  sync : 0,
  deasync : 0,
  when : 'instant', /* instant / afterdeath / time / delay */
  dry : 0, /* qqq for Yevhen : cover the option. make sure all con* called once. make sure all con* called in correct order */

  mode : 'shell', /* fork / spawn / shell */
  stdio : 'pipe', /* pipe / ignore / inherit */
  ipc : null,

  logger : null,
  procedure : null,
  stack : null,

  ready : null,
  conStart : null,
  conTerminate : null,
  conDisconnect : null,

  env : null,
  detaching : 0,
  windowHiding : 1,
  passingThrough : 0,
  concurrent : 0,
  timeOut : null,
  // returningOptionsArray : 1, /* returns array of maps of options for multiprocess launch in sync mode */ /* xxx : remove the option */

  throwingExitCode : 1, /* must be on by default */
  applyingExitCode : 0,
  briefExitCode : 0,

  verbosity : 2, /* qqq for Yevhen : cover the option */
  outputPrefixing : 0, /* qqq for Yevhen : cover the option */
  outputPiping : null, /* qqq for Yevhen : cover the option */
  outputCollecting : 0,
  outputAdditive : null, /* qqq for Yevhen : cover the option */
  outputDecorating : 0, /* qqq for Yevhen : cover the option */
  outputDecoratingStderr : null, /* qqq for Yevhen : cover the option */
  outputDecoratingStdout : null, /* qqq for Yevhen : cover the option */
  outputGraying : 0,
  inputMirroring : 1, /* qqq for Yevhen : cover the option */

}

/* xxx : move advanced options to _.process.start() */
/* xxx : add option stdio and other? */

let startSingle = _.routineFromPreAndBody( startSingle_pre, startSingle_body );

//

function start_pre( routine, args )
{
  let o = startCommon_pre( routine, args );

  _.assert( arguments.length === 2 );

  _.assert
  (
    o.execPath === null || _.strIs( o.execPath ) || _.strsAreAll( o.execPath )
    , `Expects string or strings {-o.execPath-}, but got ${_.strType( o.execPath )}`
  );
  _.assert
  (
    o.currentPath === null || _.strIs( o.currentPath ) || _.strsAreAll( o.currentPath )
    , `Expects string or strings {-o.currentPath-}, but got ${_.strType( o.currentPath )}`
  );

  return o;
}

//

/**
 * @summary Executes command in a controled child process.
 *
 * @param {Object} o Options map
 * @param {String} o.execPath Command to execute, path to application, etc.
 * @param {String} o.currentPath Current working directory of child process.

 * @param {Boolean} o.sync=0 Execute command in synchronous mode.
   There are two synchrounous modes: first uses sync method of `ChildProcess` module , second uses async method, but in combination with {@link https://www.npmjs.com/package/deasync deasync} and `wConsequence` to turn async execution into synchrounous.
   Which sync mode will be selected depends on value of `o.deasync` option.
   Sync mode returns options map.
   Async mode returns instance of {@link module:Tools/base/Consequence.Consequence wConsequence} with gives a message( options map ) when execution of child process is finished.
 * @param {Boolean} o.deasync=1 Controls usage of `deasync` module in synchrounous mode. Allows to run command synchrounously in modes( o.mode ) that don't support synchrounous execution, like `fork`.

 * @param {Array} o.args=null Arguments for command.
 * @param {Array} o.interpreterArgs=null Arguments for node. Used only in `fork` mode. {@link https://nodejs.org/api/cli.html Command Line Options}
 * @param {String} o.mode='shell' Execution mode. Possible values: `fork`, `spawn`, `shell`. {@link https://nodejs.org/api/child_process.html Details about modes}
 * @param {Object} o.ready=null `wConsequence` instance that gives a message when execution is finished.
 * @param {Object} o.logger=null `wLogger` instance that prints output during command execution.

 * @param {Object} o.env=null Environment variables( key-value pairs ).
 * @param {String/Array} o.stdio='pipe' Controls stdin,stdout configuration. {@link https://nodejs.org/api/child_process.html#child_process_options_stdio Details}
 * @param {Boolean} o.ipc=0  Creates `ipc` channel between parent and child processes.
 * @param {Boolean} o.detaching=0 Creates independent process for a child. Allows child process to continue execution when parent process exits. Platform dependent option. {@link https://nodejs.org/api/child_process.html#child_process_options_detached Details}.
 * @param {Boolean} o.windowHiding=1 Hide the child process console window that would normally be created on Windows. {@link https://nodejs.org/api/child_process.html#child_process_child_process_spawn_command_args_options Details}.
 * @param {Boolean} o.passingThrough=0 Allows to pass arguments of parent process to the child process.
 * @param {Boolean} o.concurrent=0 Allows paralel execution of several child processes. By default executes commands one by one.
 * @param {Number} o.timeOut=null Time in milliseconds before execution will be terminated.

 * @param {Boolean} o.throwingExitCode=1 Throws an Error if child process returns non-zero exit code. Child returns non-zero exit code if it was terminated by parent, timeOut or when internal error occurs.

 * @param {Boolean} o.applyingExitCode=0 Applies exit code to parent process.

 * @param {Number} o.verbosity=2 Controls amount of output, `0` disables output at all.
 * @param {Boolean} o.outputDecorating=0 Logger prints everything in raw mode, no styles applied.
 * @param {Boolean} o.outputDecoratingStdout=0 Logger prints output from `stdout` in raw mode, no styles applied.
 * @param {Boolean} o.outputDecoratingStderr=0 Logger prints output from `stderr` in raw mode, no styles applied.
 * @param {Boolean} o.outputPrefixing=0 Add prefix with name of output channel( stderr, stdout ) to each line.
 * @param {Boolean} o.outputPiping=null Handles output from `stdout` and `stderr` channels. Is enabled by default if `o.verbosity` levels is >= 2 and option is not specified explicitly. This option is required by other "output" options that allows output customization.
 * @param {Boolean} o.outputCollecting=0 Enables coullection of output into sinle string. Collects output into `o.output` property if enabled.
 * @param {Boolean} o.outputAdditive=null Prints output during execution. Enabled by default if shell executes only single command and option is not specified explicitly.
 * @param {Boolean} o.inputMirroring=1 Print complete input line before execution: path to command, arguments.
 *
 * @return {Object} Returns `wConsequence` instance in async mode. In sync mode returns options map. Options map contains not only input options, but child process descriptor, collected output, exit code and other useful info.
 *
 * @example //short way, command and arguments in one string
 *
 * let _ = require( 'wTools' )
 * _.include( 'wProcessBasic' )
 * _.include( 'wConsequence' )
 * _.include( 'wLogger' )
 *
 * let con = _.process.start( 'node -v' );
 *
 * con.then( ( op ) =>
 * {
 *  console.log( 'ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * @example //command and arguments as options
 *
 * let _ = require( 'wTools' )
 * _.include( 'wProcessBasic' )
 * _.include( 'wConsequence' )
 * _.include( 'wLogger' )
 *
 * let con = _.process.start({ execPath : 'node', args : [ '-v' ] });
 *
 * con.then( ( op ) =>
 * {
 *  console.log( 'ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * @function shell
 * @module Tools/base/ProcessBasic
 * @namespace Tools.process
 */

function start_body( o )
{

  /* subroutines index :

  form0,
  form1,
  form2,
  run1,
  run2,
  end1,
  end2,

*/

  _.assert( arguments.length === 1, 'Expects single argument' );

  let readyCallback; /* xxx : cover and implement ready callback for multiple */

  form0();

  if( _.arrayIs( o.execPath ) || _.arrayIs( o.currentPath ) )
  return run1();

  return _.process.startSingle.body.call( this, o );

  /* */

  function form0()
  {

    if( o.procedure === null || _.boolLikeTrue( o.procedure ) )
    o.stack = _.Procedure.Stack( o.stack, 3 );
  }

  /* */

  function form1()
  {

    if( o.ready === null )
    {
      o.ready = new _.Consequence().take( null );
    }
    else if( !_.consequenceIs( o.ready ) )
    {
      readyCallback = o.ready;
      _.assert( _.routineIs( readyCallback ) );
      o.ready = new _.Consequence().take( null );
    }

    _.assert( !_.consequenceIs( o.ready ) || o.ready.resourcesCount() <= 1 );

    o.logger = o.logger || _global.logger;

  }

  /* */

  function form2()
  {

    _.assert( _.boolLike( o.outputDecorating ) );
    _.assert( _.boolLike( o.outputDecoratingStdout ) );
    _.assert( _.boolLike( o.outputDecoratingStderr ) );
    _.assert( _.boolLike( o.outputCollecting ) );

    if( _.arrayIs( o.execPath ) && o.execPath.length > 1 && o.concurrent && o.outputAdditive === null )
    o.outputAdditive = 0;
    o.currentPath = o.currentPath || _.path.current();

    o.runs = [];
    // o.disconnect = disconnect; /* xxx */
    o.state = 'initial'; /* `initial`, `starting`, `started`, `terminating`, `terminated`, `disconnected` */
    o.exitReason = null;
    o.exitCode = null;
    o.exitSignal = null;
    o.error = null;
    o.procedure = null;
    o.output = o.outputCollecting ? '' : null;
    o.ended = false;

    if( !o.dry )
    if( o.procedure === null || _.boolLikeTrue( o.procedure ) )
    {
      o.procedure = _.procedure.begin({ _object : o, _stack : o.stack });
    }

  }

  /* */

  function run1()
  {

    form1();
    form2();

    o.ready
    .then( run2 )
    .finally( end2 )
    ;

    return end1();
  }

  /* */

  function run2()
  {
    let prevReady = new _.Consequence().take( null );
    let readies = [];
    let execPath = _.arrayAs( o.execPath );
    let currentPath = _.arrayAs( o.currentPath );

    for( let p = 0 ; p < execPath.length ; p++ )
    for( let c = 0 ; c < currentPath.length ; c++ )
    {

      let currentReady = new _.Consequence();
      readies.push( currentReady );

      if( o.concurrent ) /* xxx : coverage? */
      {
        prevReady.then( currentReady );
      }
      else
      {
        prevReady.finally( currentReady );
        prevReady = currentReady;
      }

      let o2 = _.mapExtend( null, o );
      o2.conStart = null;
      o2.conTerminate = null;
      o2.conDisconnect = null;
      o2.execPath = execPath[ p ];
      o2.args = o.args ? o.args.slice() : o.args;
      o2.currentPath = currentPath[ c ];
      o2.ready = currentReady;
      delete o2.runs;
      delete o2.output;
      delete o2.state;
      delete o2.exitReason;
      delete o2.exitCode;
      delete o2.exitSignal;
      delete o2.error;
      delete o2.ended;
      o.runs.push( o2 );
      _.assertMapHasAll( o2, _.process.startSingle.defaults );
      _.process.startSingle.body.call( _.process, o2 );
    }

    return _.Consequence.AndKeep( ... readies );
  }

  /* */

  function end1()
  {
    if( o.deasync )
    {
      o.ready.deasync();
      if( o.sync )
      return o.ready.sync();
    }
    if( o.sync ) /* xxx : make similar change in startSingle() */
    return o.ready.sync();
    return o.ready;
  }

  /* */

  function end2( err, arg )
  {
    o.state = 'terminated';
    o.ended = true;

    if( o.procedure.isAlive() )
    o.procedure.end();

    if( o.exitCode === null && !o.exitSginal )
    for( let a = 0 ; a < o.runs.length ; a++ )
    {
      let o2 = o.runs[ a ];
      if( o2.exitCode || o2.exitSginal !== null )
      {
        o.exitCode = o2.exitCode;
        o.exitSignal = o2.exitSignal;
        o.exitReason = o2.exitReason;
        break;
      }
    }

    if( !o.error )
    for( let a = 0 ; a < o.runs.length ; a++ )
    {
      let o2 = o.runs[ a ];
      if( o2.error )
      {
        o.error = o2.error;
        o.exitReason = o2.exitReason;
        break;
      }
    }

    for( let a = 0 ; a < o.runs.length ; a++ )
    {
      let o2 = o.runs[ a ];
      o.output += o2.output;
    }

    if( err && !o.error )
    o.error = err;

    if( err )
    throw err;

    return o;
  }

  /* */

}

start_body.defaults =
{

  ... startSingle.defaults,

}

/* xxx : implement test with throwing error in the first process */

let start = _.routineFromPreAndBody( start_pre, start_body );

//

let startPassingThrough = _.routineFromPreAndBody( start_pre, start_body );

var defaults = startPassingThrough.defaults;

defaults.verbosity = 0;
defaults.passingThrough = 1;
defaults.applyingExitCode = 1;
defaults.throwingExitCode = 0;
defaults.outputPiping = 1;
defaults.stdio = 'inherit';
defaults.mode = 'spawn';

//

/**
 * @summary Short-cut for {@link module:Tools/base/ProcessBasic.Tools.process.start start} routine. Executes provided script in with `node` runtime.
 * @description
 * Expects path to javascript file in `o.execPath` option. Automatically prepends `node` prefix before script path `o.execPath`.
 * @param {Object} o Options map, see {@link module:Tools/base/ProcessBasic.Tools.process.start start} for detailed info about options.
 * @param {Boolean} o.passingThrough=0 Allows to pass arguments of parent process to the child process.
 * @param {Boolean} o.maximumMemory=0 Allows `node` to use all available memory.
 * @param {Boolean} o.applyingExitCode=1 Applies exit code to parent process.
 * @param {String|Array} o.stdio='inherit' Prints all output through stdout,stderr channels of parent.
 *
 * @return {Object} Returns `wConsequence` instance in async mode. In sync mode returns options map. Options map contains not only input options, but child process descriptor, collected output, exit code and other useful info.
 *
 * @example
 *
 * let _ = require( 'wTools' )
 * _.include( 'wProcessBasic' )
 * _.include( 'wConsequence' )
 * _.include( 'wLogger' )
 *
 * let con = _.process.startNjs({ execPath : 'path/to/script.js' });
 *
 * con.then( ( op ) =>
 * {
 *  console.log( 'ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * @function startNjs
 * @module Tools/base/ProcessBasic
 * @namespace Tools.process
 */

function startNjs_body( o )
{

  if( !System )
  System = require( 'os' );

  _.include( 'wPathBasic' );
  _.include( 'wFiles' );

  _.assertRoutineOptions( startNjs_body, o );
  _.assert( _.strIs( o.execPath ) );
  _.assert( !o.code );
  _.assert( arguments.length === 1, 'Expects single argument' );

  /*
  1024*1024 for megabytes
  1.4 factor found empirically for windows
      implementation of nodejs for other OSs could be able to use more memory
  */

  let logger = o.logger || _global.logger;
  let interpreterArgs = '';
  if( o.maximumMemory )
  {
    let totalmem = System.totalmem();
    if( o.verbosity >= 3 )
    logger.log( 'System.totalmem()', _.strMetricFormatBytes( totalmem ) );
    if( totalmem < 1024*1024*1024 )
    Math.floor( ( totalmem / ( 1024*1024*1.4 ) - 1 ) / 256 ) * 256;
    else
    Math.floor( ( totalmem / ( 1024*1024*1.1 ) - 1 ) / 256 ) * 256;
    interpreterArgs = '--expose-gc --stack-trace-limit=999 --max_old_space_size=' + totalmem;
    interpreterArgs = _.strSplitNonPreserving({ src : interpreterArgs });
  }

  let execPath = o.execPath ? _.fileProvider.path.nativizeTolerant( o.execPath ) : '';

  _.assert( o.interpreterArgs === null || o.interpreterArgs === '', 'not implemented' ); /* qqq for Yevhen : implement and cover */

  if( o.mode === 'fork' )
  {
    if( interpreterArgs )
    o.interpreterArgs = interpreterArgs;
  }
  else
  {
    execPath = _.strConcat([ 'node', interpreterArgs, execPath ]);
  }

  o.execPath = execPath;

  let result = _.process.start.body.call( _.process, o );

  return result;
}

var defaults = startNjs_body.defaults = Object.create( start.defaults );

defaults.passingThrough = 0;
defaults.maximumMemory = 0;
defaults.applyingExitCode = 1;
defaults.stdio = 'inherit';
defaults.mode = 'fork';

let startNjs = _.routineFromPreAndBody( start_pre, startNjs_body );

//

/**
 * @summary Short-cut for {@link module:Tools/base/ProcessBasic.Tools.process.startNjs startNjs} routine.
 * @description
 * Passes arguments of parent process to the child and allows `node` to use all available memory.
 * Expects path to javascript file in `o.execPath` option. Automatically prepends `node` prefix before script path `o.execPath`.
 * @param {Object} o Options map, see {@link module:Tools/base/ProcessBasic.Tools.process.start start} for detailed info about options.
 * @param {Boolean} o.passingThrough=1 Allows to pass arguments of parent process to the child process.
 * @param {Boolean} o.maximumMemory=1 Allows `node` to use all available memory.
 * @param {Boolean} o.applyingExitCode=1 Applies exit code to parent process.
 *
 * @return {Object} Returns `wConsequence` instance in async mode. In sync mode returns options map. Options map contains not only input options, but child process descriptor, collected output, exit code and other useful info.
 *
 * @example
 *
 * let _ = require( 'wTools' )
 * _.include( 'wProcessBasic' )
 * _.include( 'wConsequence' )
 * _.include( 'wLogger' )
 *
 * let con = _.process.startNjsPassingThrough({ execPath : 'path/to/script.js' });
 *
 * con.then( ( op ) =>
 * {
 *  console.log( 'ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * @function startNjsPassingThrough
 * @module Tools/base/ProcessBasic
 * @namespace Tools.process
 */

let startNjsPassingThrough = _.routineFromPreAndBody( start_pre, startNjs.body );

var defaults = startNjsPassingThrough.defaults;

defaults.verbosity = 0;
defaults.passingThrough = 1;
defaults.maximumMemory = 1;
defaults.applyingExitCode = 1;
defaults.throwingExitCode = 0;
defaults.mode = 'fork';

//

function startAfterDeath_body( o )
{
  _.assertRoutineOptions( startAfterDeath_body, o );
  _.assert( _.strIs( o.execPath ) );
  _.assert( arguments.length === 1, 'Expects single argument' );

  let toolsPath = _.path.nativize( _.path.join( __dirname, '../../../../wtools/Tools.s' ) );
  let locals = { toolsPath, o };
  let secondaryProcessRoutine = _.program.preform({ routine : afterDeathSecondaryProcess, locals })
  let secondaryFilePath = _.process.tempOpen({ sourceCode : secondaryProcessRoutine.sourceCode });

  o.execPath = _.path.nativize( secondaryFilePath );
  o.mode = 'fork';
  o.args = [];
  o.detaching = true;
  o.inputMirroring = 0;
  o.outputPiping = 1;
  o.stdio = 'pipe';

  let result = _.process.start( o );

  o.conStart.give( function( err, op )
  {
    if( !err )
    o.process.send( true );
    this.take( err, op );
  })

  return result;

  /* */

  function afterDeathSecondaryProcess()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    process.on( 'message', () =>
    {
      process.on( 'disconnect', () => _.process.start( o ) )
    })
  }

}

var defaults = startAfterDeath_body.defaults = Object.create( start.defaults );

let startAfterDeath = _.routineFromPreAndBody( start_pre, startAfterDeath_body );

//

/**
 * @summary Generates start routine that reuses provided option on each call.
 * @description
 * Routine vectorize `o.execPath` and `o.args` options. `wConsequence` instance `o.ready` can be reused to run several starts in a row, see examples.
 * @param {Object} o Options map
 *
 * @return {Function} Returns start routine with options saved as inner state.
 *
 * @example //single command execution
 *
 * let _ = require( 'wTools' )
 * _.include( 'wProcessBasic' )
 * _.include( 'wConsequence' )
 * _.include( 'wLogger' )
 *
 * let start = _.process.starter({ execPath : 'node' });
 *
 * let con = start({ args : [ '-v' ] });
 *
 * con.then( ( op ) =>
 * {
 *  console.log( 'ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * @example //multiple commands execution with same args
 *
 * let _ = require( 'wTools' )
 * _.include( 'wProcessBasic' )
 * _.include( 'wConsequence' )
 * _.include( 'wLogger' )
 *
 * let start = _.process.starter({ args : [ '-v' ]});
 *
 * let con = start({ execPath : [ 'node', 'npm' ] });
 *
 * con.then( ( op ) =>
 * {
 *  console.log( 'ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * @example
 * //multiple commands execution with same args, using sinle consequence
 * //second command will be executed when first is finished
 *
 * let _ = require( 'wTools' )
 * _.include( 'wProcessBasic' )
 * _.include( 'wConsequence' )
 * _.include( 'wLogger' )
 *
 * let ready = new _.Consequence().take( null );
 * let start = _.process.starter({ args : [ '-v' ], ready });
 *
 * start({ execPath : 'node' });
 *
 * ready.then( ( op ) =>
 * {
 *  console.log( 'node ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * start({ execPath : 'npm' });
 *
 * ready.then( ( op ) =>
 * {
 *  console.log( 'npm ExitCode:', op.exitCode );
 *  return op;
 * })
 *
 * @function starter
 * @module Tools/base/ProcessBasic
 * @namespace Tools.process
 */

function starter( o0 )
{
  _.assert( arguments.length === 0 || arguments.length === 1 );
  if( _.strIs( o0 ) )
  o0 = { execPath : o0 }
  o0 = _.routineOptions( starter, o0 );
  o0.ready = o0.ready || new _.Consequence().take( null );

  _.routineExtend( er, _.process.start );
  er.predefined = o0;

  return er;

  function er()
  {
    let o = optionsFrom( arguments[ 0 ] );
    let o00 = _.mapExtend( null, o0 );
    merge( o00, o );
    _.mapExtend( o, o00 )

    for( let a = 1 ; a < arguments.length ; a++ )
    {
      let o1 = optionsFrom( arguments[ a ] );
      merge( o, o1 );
      _.mapExtend( o, o1 );
    }

    return _.process.start( o );
  }

  function optionsFrom( options )
  {
    if( _.strIs( options ) || _.arrayIs( options ) )
    options = { execPath : options }
    options = options || Object.create( null );
    _.assertMapHasOnly( options, starter.defaults );
    return options;
  }

  function merge( dst, src )
  {
    if( _.strIs( src ) || _.arrayIs( src ) )
    src = { execPath : src }
    _.assertMapHasOnly( src, starter.defaults );

    if( src.execPath !== null && src.execPath !== undefined && dst.execPath !== null && dst.execPath !== undefined )
    {
      _.assert
      (
        _.arrayIs( src.execPath ) || _.strIs( src.execPath ),
        () => `Expects string or array, but got ${_.strType( src.execPath )}`
      );
      if( _.arrayIs( src.execPath ) )
      src.execPath = _.arrayFlatten( src.execPath );

      /*
      condition required, otherwise vectorization of results will be done what is not desirable
      */

      if( _.arrayIs( dst.execPath ) || _.arrayIs( src.execPath ) )
      dst.execPath = _.eachSample( [ dst.execPath, src.execPath ] ).map( ( path ) => path.join( ' ' ) );
      else
      dst.execPath = dst.execPath + ' ' + src.execPath;

      delete src.execPath;
    }

    _.mapExtend( dst, src );

    return dst;
  }

}

starter.defaults = Object.create( start.defaults );

// --
// exit
// --

/**
 * @summary Allows to set/get exit reason of current process.
 * @description Saves exit reason if argument `reason` was provided, otherwise returns current exit reason value.
 * Returns `null` if reason was not defined yet.
 * @function exitReason
 * @module Tools/base/ProcessBasic
 * @namespace Tools.process
 */

function exitReason( reason )
{
  if( !_realGlobal_.wTools )
  _realGlobal_.wTools = Object.create( null );
  if( !_realGlobal_.wTools.process )
  _realGlobal_.wTools.process = Object.create( null );
  if( _realGlobal_.wTools.process._exitReason === undefined )
  _realGlobal_.wTools.process._exitReason = null;
  if( reason === undefined )
  return _realGlobal_.wTools.process._exitReason;
  _realGlobal_.wTools.process._exitReason = reason;
  return _realGlobal_.wTools.process._exitReason;
}

//

/**
 * @summary Allows to set/get exit code of current process.
 * @description Updates exit code if argument `status` was provided and returns previous exit code. Returns current exit code if no argument provided.
 * Returns `0` if exit code was not defined yet.
 * @function exitCode
 * @module Tools/base/ProcessBasic
 * @namespace Tools.process
 */

function exitCode( status )
{
  let result;

  _.assert( arguments.length === 0 || arguments.length === 1 );
  _.assert( status === undefined || _.numberIs( status ) );

  if( _global.process )
  {
    result = process.exitCode || 0;
    if( status !== undefined )
    process.exitCode = status;
  }

  return result;
}

//

function exit( exitCode )
{

  exitCode = exitCode !== undefined ? exitCode : _.process.exitCode();

  _.assert( arguments.length === 0 || arguments.length === 1 );
  _.assert( exitCode === undefined || _.numberIs( exitCode ) );

  if( _global.process )
  {
    process.exit( exitCode );
  }
  else
  {
    /*debugger;*/
  }

}

//

// function exitWithBeep( exitCode )
function exitWithBeep()
{
  let exitCode = _.process.exitCode();

  // exitCode = exitCode !== undefined ? exitCode : _.process.exitCode();
  // _.assert( arguments.length === 0 || arguments.length === 1 );
  _.assert( arguments.length === 0, 'Expects no arguments' );
  _.assert( exitCode === undefined || _.numberIs( exitCode ) );

  _.diagnosticBeep();

  if( exitCode )
  _.diagnosticBeep();

  _.process.exit( exitCode );

  return exitCode;
}

//

_realGlobal_._exitHandlerRepairDone = _realGlobal_._exitHandlerRepairDone || 0;
_realGlobal_._exitHandlerRepairTerminating = _realGlobal_._exitHandlerRepairTerminating || 0;
function _exitHandlerRepair()
{

  _.assert( arguments.length === 0, 'Expects no arguments' );

  if( _realGlobal_._exitHandlerRepairDone )
  return;
  _realGlobal_._exitHandlerRepairDone = 1;

  if( !_global.process )
  return;

  // process.on( 'SIGHUP', handle_functor( 'SIGHUP', 1 ) ); /* yyy */
  process.on( 'SIGQUIT', handle_functor( 'SIGQUIT', 3 ) );
  process.on( 'SIGINT', handle_functor( 'SIGINT' ), 2 );
  process.on( 'SIGTERM', handle_functor( 'SIGTERM' ), 15 );
  process.on( 'SIGUSR1', handle_functor( 'SIGUSR1' ), 16 );
  process.on( 'SIGUSR2', handle_functor( 'SIGUSR2' ), 17 );

  function handle_functor( signal, signalCode )
  {
    return function handle()
    {
      console.log( signal );
      if( _realGlobal_._exitHandlerRepairTerminating )
      return;
      _realGlobal_._exitHandlerRepairTerminating = 1;
      _.time.begin( _.process._sanitareTime, () => /* xxx : experiment to remove delay */
      {
        try
        {
          process.removeListener( signal, handle );
          if( !process._exiting )
          {
            try
            {
              process._exiting = true;
              process.emit( 'exit', 128 + signalCode );
            }
            catch( err )
            {
              console.error( _.err( err ) );
            }
            process.kill( process.pid, signal );
          }
        }
        catch( err )
        {
          console.log( `Error on signal ${signal}` );
          console.log( err.toString() );
          console.log( err.stack );
          process.removeAllListeners( 'exit' );
          process.exit();
        }
      });
    }
  }

}

//

function _eventExitSetup()
{

  _.assert( arguments.length === 0, 'Expects no arguments' );

  if( !_global.process )
  return;

  if( !_.process._registeredExitHandler )
  {
    _global.process.once( 'exit', _.process._eventExitHandle );
    _.process._registeredExitHandler = _.process._eventExitHandle;
    // process.once( 'SIGINT', onExitHandler );
    // process.once( 'SIGTERM', onExitHandler );
  }

}

//

function _eventExitHandle()
{
  let args = arguments;
  _.process.eventGive({ event : 'exit', args });
  process.removeListener( 'exit', _.process._registeredExitHandler );
  // process.removeListener( 'SIGINT', _.process._registeredExitHandler );
  // process.removeListener( 'SIGTERM', _.process._registeredExitHandler );
  _.process._ehandler.events.exit.splice( 0, _.process._ehandler.events.exit.length );
}

// --
// children
// --

function isAlive( src )
{
  let pid = _.process.pidFrom( src );
  _.assert( arguments.length === 1 );
  _.assert( _.numberIs( pid ), `Expects process id as number, but got:${pid}` );

  try
  {
    return process.kill( pid, 0 );
  }
  catch( err )
  {
    return err.code === 'EPERM'
  }

}

//

function pidFrom( src )
{
  _.assert( arguments.length === 1 );

  if( !ChildProcess )
  ChildProcess = require( 'child_process' );

  if( _.numberIs( src ) )
  return src;
  if( _.objectIs( src ) )
  {
    if( src.process )
    src = src.process;
    if( src.pnd )
    src = src.pnd;
    _.assert( src instanceof ChildProcess.ChildProcess );
    return src.pid;
  }

  _.assert( 0, `Unexpected source:${src}` );
}

//

function statusOf( src )
{
  _.assert( arguments.length === 1 );
  let isAlive = _.process.isAlive( src );
  return isAlive ? 'alive' : 'dead';
}

//

function signal_pre( routine, args )
{
  let o = args[ 0 ];

  _.assert( args.length === 1 );

  if( _.numberIs( o ) )
  o = { pid : o };
  else if( _.routineIs( o.kill ) )
  o = { pnd : o };

  o = _.routineOptions( routine, o );

  if( o.pnd )
  {
    _.assert( o.pid === null );
    o.pid = o.pnd.pid;
  }

  return o;
}

//

function signal_body( o )
{
  _.assert( arguments.length === 1 );
  _.assert( _.numberIs( o.timeOut ), 'Expects number as option {-timeOut-}' );
  _.assert( _.strIs( o.signal ), 'Expects signal to be provided explicitly as string' );
  _.assert( _.intIs( o.pid ) );

  let isWindows = process.platform === 'win32';
  let ready = _.Consequence().take( null );
  let cons = [];
  let interval = isWindows ? 150 : 25;
  /*
    xxx : hangs up on Windows with interval 25 if run in sync mode. see test routine killSync
  */

  // console.log( 'killing', o.pid );

  ready.then( () =>
  {
    if( o.withChildren )
    return _.process.children({ pid : o.pid, format : 'list' });
    return { pid : o.pid, pnd : o.pnd };
  })

  ready.then( processKill );
  ready.then( handleResult );
  ready.catch( handleError );

  if( o.sync )
  ready.deasync();

  return ready;

  /* - */

  function signalSend( p )
  {
    _.assert( _.intIs( p.pid ) );

    if( !_.process.isAlive( p.pid ) )
    return;

    let pnd = p.pnd;
    if( !pnd && o.pnd && o.pnd.pid === p.pid )
    pnd = o.pnd;

    // console.log( o.signal, p.pid );

    if( pnd )
    pnd.kill( o.signal );
    else
    process.kill( p.pid, o.signal );

    // if( !o.timeOut )
    // return;

    let con = waitForTermination( p.pid );
    cons.push( con );
  }

  /* */

  function processKill( processes )
  {

    _.assert( !o.withChildren || o.pid === processes[ 0 ].pid, 'Something wrong, first process must be the leader' );

    // if( o.withChildren )
    // {
    //   console.log( `pid : ${o.pid}` );
    //   console.log( `pids' : ${processes}` );
    //   debugger;
    // }

    /*
      leader of the group of processes should receive the signal first
      so progression sould be positive
    */

    if( o.withChildren )
    // for( let i = processes.length - 1; i >= 0; i-- )
    for( let i = 0 ; i < processes.length ; i++ )
    {
      if( isWindows && i && processes[ i ].name === 'conhost.exe' )
      continue;
      signalSend( processes[ i ] );
    }
    else
    {
      signalSend( processes );
    }

    if( !cons.length )
    return true;

    return _.Consequence.AndKeep( ... cons );
  }

  /* - */

  function waitForTermination( pid )
  {
    var ready = _.Consequence();
    var timer;
    timer = _.time._periodic( interval, () =>
    {
      if( _.process.isAlive( pid ) )
      return false;
      // timer._cancel(); /* zzz yyy : remove? */
      ready.take( true );
      // return true;
      /* Dmytro ; new implementation of periodic timer require to return something different to undefined or _.dont.
         Otherwise, timer will be canceled. This code does not affect current behavior of routines and will work with
         new behavior.

         When module Tools will be updated, we can use next code instead of current :

        if( _.process.isAlive( o.pid ) )
        return false;
        ready.take( true );
       */
    });

    let timeOutError = _.time.outError( o.timeOut )

    ready.orKeeping( [ timeOutError ] );

    ready.finally( ( err, op ) =>
    {
      if( !timeOutError.resourcesCount() ) /* xxx : rewrite */
      timeOutError.take( _.dont );

      if( err )
      {
        timer._cancel(); /* xxx : rewrite */
        _.errAttend( err );
        if( err.reason === 'time out' )
        err = _.err( err, `\nTarget process: ${_.strQuote( pid )} is still alive. Waited for ${o.timeOut} ms.` );
        throw err;
      }
      return op;
    })

    return ready;
  }

  /* - */

  function handleError( err )
  {
    // if( err.code === 'EINVAL' )
    // throw _.err( err, '\nAn invalid signal was specified:', _.strQuote( o.signal ) )
    if( err.code === 'EPERM' )
    throw _.err( err, '\nCurrent process does not have permission to kill target process' );
    if( err.code === 'ESRCH' )
    throw _.err( err, `\nTarget process: ${_.strQuote( o.pid )} does not exist.` ); /* qqq for Yevhen : rewrite such strings as template-strings | aaa : Done.*/
    throw _.err( err );
  }

  function handleResult( result )
  {

    result = _.arrayAs( result );

    for( let i = 0 ; i < result.length ; i++ )
    {
      if( result[ i ] !== true )
      return result[ i ];
    }

    return true;
  }

}

signal_body.defaults =
{
  pid : null,
  pnd : null,
  withChildren : 1, /* xxx : set to 1 aaa Vova:changed*/
  timeOut : 5000,
  signal : null,
  sync : 0
}

let signal = _.routineFromPreAndBody( signal_pre, signal_body );

//

function kill_body( o )
{
  _.assert( arguments.length === 1 );
  o.signal = 'SIGKILL';
  o.timeOut = signal.defaults.timeOut;
  return _.process.signal.body( o );
}

kill_body.defaults =
{
  ... _.mapBut( signal.defaults, [ 'signal', 'timeOut' ] ),
}

let kill = _.routineFromPreAndBody( signal_pre, kill_body );


//

/*
  zzz for Vova: shell mode have different behaviour on Windows, OSX and Linux
  look for solution that allow to have same behaviour on each mode
*/

function terminate_body( o )
{
  _.assert( arguments.length === 1 );

  o.signal = 'SIGTERM';

  let ready = _.process.signal.body( o );

  ready.catch( ( err ) =>
  {
    if( err.reason !== 'time out' )
    throw err;

    _.errAttend( err );

    delete o.signal;
    return _.process.kill.body( o )
    .then( () =>
    {
      throw err;
    })
  })

  if( o.sync )
  ready.deasync();

  return ready;
}

terminate_body.defaults =
{
  ... _.mapBut( signal.defaults, [ 'signal' ] ),
}

let terminate = _.routineFromPreAndBody( signal_pre, terminate_body );

//

function children( o )
{
  if( _.numberIs( o ) )
  o = { pid : o };
  else if( _.routineIs( o.kill ) )
  o = { process : o }

  _.routineOptions( children, o )
  _.assert( arguments.length === 1 );
  _.assert( _.numberIs( o.pid ) );
  _.assert( _.longHas( [ 'list', 'tree' ], o.format ) );

  if( o.process )
  {
    _.assert( o.pid === null );
    o.pid = o.process.pid;
  }

  let result;

  if( !_.process.isAlive( o.pid ) )
  {
    let err = _.err( `\nTarget process: ${_.strQuote( o.pid )} does not exist.` );
    return new _.Consequence().error( err );
  }

  if( process.platform === 'win32' )
  {
    if( !WindowsProcessTree )
    {
      try
      {
        WindowsProcessTree = require( 'wwindows-process-tree' );
      }
      catch( err )
      {
        throw _.err( 'Failed to get child process list.\n', err );
      }
    }

    let con = new _.Consequence();
    if( o.format === 'list' )
    {
      WindowsProcessTree.getProcessList( o.pid, ( result ) => con.take( result ) )
    }
    else
    {
      WindowsProcessTree.getProcessTree( o.pid, ( list ) =>
      {
        result = Object.create( null );
        handleWindowsResult( result, list );
        con.take( result );
      })
    }
    return con;
  }
  else
  {
    if( o.format === 'list' )
    result = [];
    else
    result = Object.create( null );

    if( process.platform === 'darwin' )
    return childrenOf( 'pgrep -P', o.pid, result );
    else
    return childrenOf( 'ps -o pid --no-headers --ppid', o.pid, result );
    /* qqq for Vova : use optimal solution */
  }

  /* */

  function childrenOf( command, pid, _result )
  {
    return _.process.start
    ({
      execPath : command + ' ' + pid,
      outputCollecting : 1,
      outputPiping : 0,
      throwingExitCode : 0,
      inputMirroring : 0,
      stdio : 'pipe',
    })
    .then( ( op ) =>
    {
      if( o.format === 'list' )
      _result.push({ pid : _.numberFrom( pid ) });
      else
      _result[ pid ] = Object.create( null );
      if( op.exitCode !== 0 )
      return result;
      let ready = new _.Consequence().take( null );
      let pids = _.strSplitNonPreserving({ src : op.output, delimeter : '\n' });
      _.each( pids, ( cpid ) => ready.then( () => childrenOf( command, cpid, o.format === 'list' ? _result : _result[ pid ] ) ) )
      return ready;
    })
  }

  function handleWindowsResult( tree, result )
  {
    tree[ result.pid ] = Object.create( null );
    if( result.children && result.children.length )
    _.each( result.children, ( child ) => handleWindowsResult( tree[ result.pid ], child ) )
    return tree;
  }

}

children.defaults =
{
  process : null,
  pid : null,
  format : 'list',
  // asList : 0
}

// --
// declare
// --

let Extension =
{

  // start

  startSingle,
  start,
  startPassingThrough,
  startNjs,
  startNjsPassingThrough,
  startAfterDeath,
  starter,

  // exit

  exitReason,
  exitCode,
  exit,
  exitWithBeep,

  _exitHandlerRepair, /* zzz */
  _eventExitSetup,
  _eventExitHandle,

  // children

  isAlive,
  pidFrom,
  statusOf,
  signal,
  kill,
  terminate,
  children,

  // fields

  _sanitareTime : 10,
  _exitReason : null,

}

_.mapExtend( Self, Extension );
_.assert( _.routineIs( _.process.start ) );

// --
// export
// --

if( typeof module !== 'undefined' )
module[ 'exports' ] = _;

})();
