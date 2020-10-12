( function _ProcessBasic_test_s( )
{

'use strict';

if( typeof module !== 'undefined' )
{
  let _ = require( '../../../wtools/Tools.s' );

  _.include( 'wTesting' );
  _.include( 'wFiles' );
  _.include( 'wProcessWatcher' );

  require( '../l4_process/Basic.s' );
}

let _global = _global_;
let _ = _global_.wTools;
let Self = {};


/*
### Modes in which child process terminates after signal:

| Signal  |  Windows   |   Linux    |       Mac        |
| ------- | ---------- | ---------- | ---------------- |
| SIGINT  | spawn,fork | spawn,fork | shell,spawn,fork |
| SIGKILL | spawn,fork | spawn,fork | shell,spawn,fork |

### Test routines and modes that pass test checks:

|        Routine         |  Windows   | Windows + windows-kill |   Linux    |       Mac        |
| ---------------------- | ---------- | ---------------------- | ---------- | ---------------- |
| endStructuralSigint    | spawn,fork | spawn,fork             | spawn,fork | shell,spawn,fork |
| endStructuralSigkill   | spawn,fork | spawn,fork             | spawn,fork | shell,spawn,fork |
| endStructuralTerminate |          |                      | spawn,fork | shell,spawn,fork |
| endStructuralKill      | spawn,fork | spawn,fork             | spawn,fork | shell,spawn,fork |

#### endStructuralTerminate on Windows, without windows-kill

For each mode:
exitCode : 1, exitSignal : null

Child process terminates in modes spawn and fork
Child process continues to work in mode spawn

See: doc/ProcessKillMethodsDifference.md

#### endStructuralTerminate on Windows, with windows-kill

For each mode:
exitCode : 3221225725, exitSignal : null

Child process terminates in modes spawn and fork
Child process continues to work in mode spawn

### Shell mode termination results:

| Signal  | Windows | Linux | MacOS |
| ------- | ------- | ----- | ----- |
| SIGINT  | 0       | 0     | 1     |
| SIGKILL | 0       | 0     | 1     |

0 - Child continues to work
1 - Child is terminated
*/

/*

### Info about event `close`
╔════════════════════════════════════════════════════════════════════════╗
║       mode               ipc          disconnecting      close event ║
╟────────────────────────────────────────────────────────────────────────╢
║       spawn             false             false             true     ║
║       spawn             false             true              true     ║
║       spawn             true              false             true     ║
║       spawn             true              true              false    ║
║       fork              true              false             true     ║
║       fork              true              true              false    ║
║       shell             false             false             true     ║
║       shell             false             true              true     ║
╚════════════════════════════════════════════════════════════════════════╝

Summary:

* Options `stdio` and `detaching` don't affect `close` event.
* Mode `spawn`: IPC is optionable. Event close is not called if disconnected process had IPC enabled.
* Mode `fork` : IPC is always enabled. Event close is not called if process is disconnected.
* Mode `shell` : IPC is not available. Event close is always called.
*/

/*
## Event exit

This section shows when event `exit` of child process is called. The behavior is the same for Windows,Linux and Mac.

╔════════════════════════════════════════════════════════════════════════╗
║       mode               ipc          disconnecting      event exit  ║
╟────────────────────────────────────────────────────────────────────────╢
║       spawn             false             false             true     ║
║       spawn             false             true              true     ║
║       spawn             true              false             true     ║
║       spawn             true              true              true     ║
║       fork              true              false             true     ║
║       fork              true              true              true     ║
║       shell             false             false             true     ║
║       shell             false             true              true     ║
╚════════════════════════════════════════════════════════════════════════╝

Event 'exit' is aways called. Options `stdio` and `detaching` also don't affect `exit` event.
*/

/* qqq for Yevhen : find all tests with passingThrough:1, separate them from the rest of the test
and rewrite to run process which run process to avoid influence of arguments of tester on testing
*/

/* qqq for Yevhen : parametrize all time delays, don't forget to leave comment of old value
time.out
setTimeout
*/

/* qqq for Yevhen : implement for 3 modes where test routine is not implemented for 3 modes */

// --
// context
// --

function suiteBegin()
{
  let context = this;
  context.suiteTempPath = _.path.tempOpen( _.path.join( __dirname, '../..' ), 'ProcessBasic' );
}

//

function suiteEnd()
{
  let context = this;
  _.assert( _.strHas( context.suiteTempPath, '/ProcessBasic-' ) )
  _.path.tempClose( context.suiteTempPath );
}

//

function assetFor( test, name )
{
  let context = this;
  let a = test.assetFor( name );

  _.assert( _.routineIs( a.program.pre ) );
  _.assert( _.routineIs( a.program.body ) );

  let oprogram = a.program;
  program_body.defaults = a.program.defaults;
  a.program = _.routineFromPreAndBody( a.program.pre, program_body );

  return a;

  /* */

  function program_body( o )
  {
    let locals =
    {
      context : { t0 : context.t0, t1 : context.t1, t2 : context.t2, t3 : context.t3 },
      toolsPath : _.module.resolve( 'wTools' ),
    };
    o.locals = o.locals || locals;
    _.mapSupplement( o.locals, locals );
    _.mapSupplement( o.locals.context, locals.context );
    let programPath = a.path.nativize( oprogram.body.call( a, o ) ); /* zzz : modify a.program()? */
    return programPath;
  }

}

// --
// basic
// --

function startBasic( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( mode ) ) );
  return a.ready;

  /* - */

  function run( mode )
  {
    let ready = _.Consequence().take( null );
    let o2;
    let o3 =
    {
      outputPiping : 1,
      outputCollecting : 1,
      applyingExitCode : 0,
      throwingExitCode : 1
    }

    let expectedOutput =
`${programPath}:begin
${programPath}:end
`
    ready

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode} only execPath`;

      o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return _.process.start( options )
      .then( function()
      {
        test.identical( options.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true );
        test.identical( o.state, 'terminated' );
        test.identical( options.output, expectedOutput );
        return null;
      })
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode} execPath+args, null`;

      o2 =
      {
        execPath : mode === `fork` ? null : `node`,
        args : `${programPath}`,
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return _.process.start( options )
      .then( function()
      {
        test.identical( options.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true );
        test.identical( o.state, 'terminated' );
        test.identical( options.output, expectedOutput );
        return null;
      })
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode} execPath+args, empty string`;

      o2 =
      {
        execPath : mode === `fork` ? `` : `node`,
        args : `${programPath}`,
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return _.process.start( options )
      .then( function()
      {
        test.identical( options.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true );
        test.identical( o.state, 'terminated' );
        test.identical( options.output, expectedOutput );
        return null;
      })
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode} execPath+args, null, array`;

      o2 =
      {
        execPath : mode === `fork` ? null : `node`,
        args : [ `${programPath}` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return _.process.start( options )
      .then( function()
      {
        test.identical( options.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true );
        test.identical( o.state, 'terminated' );
        test.identical( options.output, expectedOutput );
        return null;
      })
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode} execPath+args empty string array`;

      o2 =
      {
        execPath : mode === `fork` ? `` : `node`,
        args : [ `${programPath}` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return _.process.start( options )
      .then( function()
      {
        test.identical( options.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true );
        test.identical( o.state, 'terminated' );
        test.identical( options.output, expectedOutput );
        return null;
      })
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, stdio:pipe`;

      o2 =
      {
        execPath : mode === `fork` ? null : `node`,
        args : `${programPath}`,
        mode,
        stdio : 'pipe'
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return _.process.start( options )
      .then( function()
      {
        test.identical( options.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true );
        test.identical( o.state, 'terminated' );
        test.identical( options.output, expectedOutput );
        return null;
      })
    })

    /* */

    .then( function( arg )
    {
      test.case = 'mode : shell, stdio : ignore';

      o2 =
      {
        execPath : mode === `fork` ? `` : `node`,
        args : `${programPath}`,
        mode,
        stdio : 'ignore',
        outputCollecting : 0,
        outputPiping : 0,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return _.process.start( options )
      .then( function()
      {
        test.identical( options.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true );
        test.identical( o.state, 'terminated' );
        test.identical( options.output, null );
        return null;
      })
    })

    /* */

    .then( function( arg )
    {
      test.case = 'shell, return good code';

      o2 =
      {
        execPath : mode === `fork` ? `${programPath} exitWithCode : 0` : `node ${programPath} exitWithCode:0`,
        outputCollecting : 1,
        stdio : 'pipe',
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return test.mustNotThrowError( _.process.start( options ) )
      .then( () =>
      {
        test.is( !options.error );
        test.identical( options.process.killed, false );
        test.identical( options.exitCode, 0 );
        test.identical( options.exitReason, 'normal' );
        test.identical( options.ended, true );
        test.identical( options.state, 'terminated' );
        test.identical( options.exitSignal, null );
        test.identical( options.process.exitCode, 0 );
        test.identical( options.process.signalCode, null );
        test.identical( _.strCount( options.output, ':begin' ), 1 );
        test.identical( _.strCount( options.output, ':end' ), 0 );
        return null;
      });
    })

    /* */

    .then( function( arg )
    {
      test.case = 'shell, return good code';

      o2 =
      {
        execPath : mode === `fork` ? `${programPath} exitWithCode : 1` : `node ${programPath} exitWithCode:1`,
        outputCollecting : 1,
        stdio : 'pipe',
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return test.shouldThrowErrorAsync( _.process.start( options ),
      ( err, arg ) =>
      {
        test.is( _.errIs( err ) );
        test.identical( err.reason, 'exit code' );
      })
      .then( () =>
      {
        test.is( !!options.error );
        test.identical( options.process.killed, false );
        test.identical( options.exitCode, 1 );
        test.identical( options.exitSignal, null );
        test.identical( options.process.exitCode, 1 );
        test.identical( options.process.signalCode, null );
        test.identical( options.state, 'terminated' );
        test.identical( _.strCount( options.output, ':begin' ), 1 );
        test.identical( _.strCount( options.output, ':end' ), 0 );
        return null;
      });
    })

    /* */

    .then( function( arg )
    {
      test.case = 'bad args';

      o2 =
      {
        execPath : mode === `fork` ? null : `node`,
        args : `${programPath} exitWithCode : 0`,
        outputCollecting : 1,
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      return test.shouldThrowErrorAsync( _.process.start( options ),
      ( err, arg ) =>
      {
        test.is( _.errIs( err ) );
        test.identical( err.reason, 'exit code' );
      })
      .then( () =>
      {
        test.is( !!options.error );
        test.identical( options.exitCode, 1 );
        test.identical( options.exitSignal, null );
        test.identical( options.state, 'terminated' );
        test.identical( _.strCount( options.output, ':begin' ), 0 );
        test.identical( _.strCount( options.output, ':end' ), 0 );
        return null;
      });
    })

    /* - */

    return ready;
  }

  /* - */

  function program1()
  {
    console.log( `${__filename}:begin` );
    let _ = require( toolsPath );
    let process = _global_.process;

    _.include( 'wProcess' );

    var args = _.process.args();

    if( args.map.exitWithCode !== undefined )
    process.exit( args.map.exitWithCode )

    if( args.map.loop )
    _.time.out( 5000 );

    console.log( `${__filename}:end` );
  }
}

//

function startBasic2( test ) /* qqq for Evhen : merge with test routine startBasic */
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( testApp ) );

  let o3 =
  {
    outputPiping : 1,
    outputCollecting : 1,
    applyingExitCode : 0,
    throwingExitCode : 1
  }

  let o2;

  a.ready.then( function()
  {
    test.case = 'mode : shell';

    o2 =
    {
      execPath :  'node ' + programPath,
      args : [ 'staging', 'debug' ],
      mode : 'shell',
      stdio : 'pipe'
    }
    return null;
  })
  .then( function( arg )
  {
    /* mode : shell, stdio : pipe */

    var options = _.mapSupplement( {}, o2, o3 );

    return _.process.start( options )
    .then( function()
    {
      test.identical( options.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( options.output, o2.args.join( ' ' ) + '\n' );
      return null;
    })
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'mode : spawn, passingThrough : true, incorrect usage of o.path in spawn mode';

    o2 =
    {
      execPath :  'node ' + testApp,
      args : [ 'staging' ],
      mode : 'spawn',
      passingThrough : 1,
      stdio : 'pipe'
    }
    return null;
  })
  .then( function( arg )
  {
    var options = _.mapSupplement( {}, o2, o3 );
    return test.shouldThrowErrorAsync( _.process.start( options ) );
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ).join( ' ' ) );
  }
}

//

/*

  zzz : investigate please
  test routine shellFork causes

 1: node::DecodeWrite
 2: node::Start
 3: v8::RetainedObjectInfo::~RetainedObjectInfo
 4: uv_loop_size
 5: uv_disable_stdio_inheritance
 6: uv_dlerror
 7: uv_run
 8: node::CreatePlatform
 9: node::CreatePlatform
10: node::Start
11: v8_inspector::protocol::Runtime::API::StackTrace::fromJSONString
12: BaseThreadInitThunk
13: RtlUserThreadStart

*/


function startFork( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( program1 );

  /* */

  a.ready.then( function()
  {
    test.case = 'no args';

    let o =
    {
      execPath : programPath,
      args : null,
      mode : 'fork',
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
    }
    return _.process.start( o )
    .then( function( op )
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( _.strHas( o.output, '[]' ) );
      return null;
    })
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'args';

    let o =
    {
      execPath : programPath,
      args : [ 'arg1', 'arg2' ],
      mode : 'fork',
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
    }
    return _.process.start( o )
    .then( function( op )
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( _.strHas( o.output,  `[ 'arg1', 'arg2' ]` ) );
      return null;
    })
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'stdio : ignore';

    let o =
    {
      execPath : programPath,
      args : [ 'arg1', 'arg2' ],
      mode : 'fork',
      stdio : 'ignore',
      outputCollecting : 0,
      outputPiping : 0,
    }

    return _.process.start( o )
    .then( function( op )
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.output, null );
      return null;
    })
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'complex';

    function testApp2()
    {
      console.log( process.argv.slice( 2 ) );
      console.log( process.env );
      console.log( process.cwd() );
      console.log( process.execArgv );
    }

    let programPath = a.program( testApp2 );

    let o =
    {
      execPath : programPath,
      currentPath : a.routinePath,
      env : { 'key1' : 'val' },
      args : [ 'arg1', 'arg2' ],
      interpreterArgs : [ '--no-warnings' ],
      mode : 'fork',
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
    }
    return _.process.start( o )
    .then( function( op )
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( _.strHas( o.output,  `[ 'arg1', 'arg2' ]` ) );
      test.is( _.strHas( o.output,  `key1: 'val'` ) );
      test.is( _.strHas( o.output,  a.path.nativize( a.routinePath ) ) );
      test.is( _.strHas( o.output,  `[ '--no-warnings' ]` ) );

      return null;
    })
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'complex + deasync';

    function testApp3()
    {
      console.log( process.argv.slice( 2 ) );
      console.log( process.env );
      console.log( process.cwd() );
      console.log( process.execArgv );
    }

    let programPath = a.program( testApp3 );

    let o =
    {
      execPath :   programPath,
      currentPath : a.routinePath,
      env : { 'key1' : 'val' },
      args : [ 'arg1', 'arg2' ],
      interpreterArgs : [ '--no-warnings' ],
      mode : 'fork',
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
      sync : 1,
      deasync : 1
    }

    _.process.start( o );
    debugger
    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );
    test.is( _.strHas( o.output,  `[ 'arg1', 'arg2' ]` ) );
    test.is( _.strHas( o.output,  `key1: 'val'` ) );
    test.is( _.strHas( o.output,  a.path.nativize( a.routinePath ) ) );
    test.is( _.strHas( o.output,  `[ '--no-warnings' ]` ) );

    return null;
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'test is ipc works';

    function testApp4()
    {
      process.on( 'message', ( e ) =>
      {
        process.send({ message : 'child received ' + e.message })
        process.exit();
      })
    }

    let programPath = a.program( testApp4 );

    let o =
    {
      execPath :   programPath,
      mode : 'fork',
      stdio : 'pipe',
    }

    let gotMessage;
    let con = _.process.start( o );

    o.process.send({ message : 'message from parent' });
    o.process.on( 'message', ( e ) =>
    {
      gotMessage = e.message;
    })

    con.then( function( op )
    {
      test.identical( gotMessage, 'child received message from parent' )
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return null;
    })

    return con;
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'execPath can contain path to js file and arguments';

    let o =
    {
      execPath :   programPath + ' arg0',
      mode : 'fork',
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
    }

    return _.process.start( o )
    .then( function( op )
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( _.strHas( o.output,  `[ 'arg0' ]` ) );
      return null;
    })
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'test timeOut';

    function testApp5()
    {
      setTimeout( () =>
      {
        console.log( 'timeOut' );
      }, 5000 )
    }

    let programPath = a.program( testApp5 );

    let o =
    {
      execPath :   programPath,
      mode : 'fork',
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
      throwingExitCode : 1,
      timeOut : 1000,
    }

    return test.shouldThrowErrorAsync( _.process.start( o ) )
    .then( function( op )
    {
      test.identical( o.exitCode, null );
      return null;
    })
  })

  /* */

  a.ready.then( function()
  {
    test.case = 'test timeOut';

    function testApp6()
    {
      setTimeout( () =>
      {
        console.log( 'timeOut' );
      }, 5000 )
    }

    let programPath = a.program( testApp6 );

    let o =
    {
      execPath :   programPath,
      mode : 'fork',
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
      throwingExitCode : 0,
      timeOut : 1000,
    }

    return _.process.start( o )
    .then( function( op )
    {
      test.identical( o.exitCode, null );
      return null;
    })
  })

  return a.ready;

  /* - */

  function program1()
  {
    console.log( process.argv.slice( 2 ) );
  }

}

//

function startErrorHandling( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( program1 );
  let testAppPath2 = a.program( program2 );

  /* */

  a.ready.then( function()
  {
    test.case = 'collecting, verbosity and piping off';

    let o =
    {
      execPath :   'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'pipe',
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) )
    .then( function( op )
    {
      test.is( _.errIs( op ) );
      test.is( _.strHas( op.message, 'Process returned exit code' ) )
      test.is( _.strHas( op.message, 'Launched as' ) )
      test.is( _.strHas( op.message, 'Stderr' ) )
      test.is( _.strHas( op.message, 'Error message from child' ) )

      test.notIdentical( o.exitCode, 0 );

      return null;
    })

  })

  /* */

  a.ready.then( function()
  {
    test.case = 'collecting, verbosity and piping off';

    let o =
    {
      execPath :   'node ' + testAppPath,
      mode : 'shell',
      stdio : 'pipe',
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) )
    .then( function( op )
    {
      test.is( _.errIs( op ) );
      test.is( _.strHas( op.message, 'Process returned exit code' ) )
      test.is( _.strHas( op.message, 'Launched as' ) )
      test.is( _.strHas( op.message, 'Stderr' ) )
      test.is( _.strHas( op.message, 'Error message from child' ) )

      test.notIdentical( o.exitCode, 0 );

      return null;
    })

  })

  /* */

  a.ready.then( function()
  {
    test.case = 'collecting, verbosity and piping off';

    let o =
    {
      execPath :   testAppPath,
      mode : 'fork',
      stdio : 'pipe',
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) )
    .then( function( op )
    {
      test.is( _.errIs( op ) );
      test.is( _.strHas( op.message, 'Process returned exit code' ) )
      test.is( _.strHas( op.message, 'Launched as' ) )
      test.is( _.strHas( op.message, 'Stderr' ) )
      test.is( _.strHas( op.message, 'Error message from child' ) )

      test.notIdentical( o.exitCode, 0 );

      return null;
    })

  })

  /* */

  a.ready.then( function()
  {
    test.case = 'sync, collecting, verbosity and piping off';

    let o =
    {
      execPath :   'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'pipe',
      sync : 1,
      deasync : 1,
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }
    var returned = test.shouldThrowErrorSync( () => _.process.start( o ) )

    test.is( _.errIs( returned ) );
    test.is( _.strHas( returned.message, 'Process returned exit code' ) )
    test.is( _.strHas( returned.message, 'Launched as' ) )
    test.is( _.strHas( returned.message, 'Stderr' ) )
    test.is( _.strHas( returned.message, 'Error message from child' ) )

    test.notIdentical( o.exitCode, 0 );

    return null;

  })

  /* */

  a.ready.then( function()
  {
    test.case = 'sync, collecting, verbosity and piping off';

    let o =
    {
      execPath :   'node ' + testAppPath,
      mode : 'shell',
      stdio : 'pipe',
      sync : 1,
      deasync : 1,
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }
    var returned = test.shouldThrowErrorSync( () => _.process.start( o ) )

    test.is( _.errIs( returned ) );
    test.is( _.strHas( returned.message, 'Process returned exit code' ) )
    test.is( _.strHas( returned.message, 'Launched as' ) )
    test.is( _.strHas( returned.message, 'Stderr' ) )
    test.is( _.strHas( returned.message, 'Error message from child' ) )

    test.notIdentical( o.exitCode, 0 );

    return null;

  })

  /* */

  a.ready.then( function()
  {
    test.case = 'sync, collecting, verbosity and piping off';

    let o =
    {
      execPath :   testAppPath,
      mode : 'fork',
      stdio : 'pipe',
      sync : 1,
      deasync : 1,
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }
    var returned = test.shouldThrowErrorSync( () => _.process.start( o ) )

    test.is( _.errIs( returned ) );
    test.is( _.strHas( returned.message, 'Process returned exit code' ) )
    test.is( _.strHas( returned.message, 'Launched as' ) )
    test.is( _.strHas( returned.message, 'Stderr' ) )
    test.is( _.strHas( returned.message, 'Error message from child' ) )

    test.notIdentical( o.exitCode, 0 );

    return null;

  })

  /* */

  a.ready.then( function()
  {
    test.case = 'stdio ignore, sync, collecting, verbosity and piping off';

    let o =
    {
      execPath :   testAppPath,
      mode : 'fork',
      stdio : 'ignore',
      sync : 1,
      deasync : 1,
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }
    var returned = test.shouldThrowErrorSync( () => _.process.start( o ) )

    test.is( _.errIs( returned ) );
    test.is( _.strHas( returned.message, 'Process returned exit code' ) )
    test.is( _.strHas( returned.message, 'Launched as' ) )
    test.is( !_.strHas( returned.message, 'Stderr' ) )
    test.is( !_.strHas( returned.message, 'Error message from child' ) )

    test.notIdentical( o.exitCode, 0 );

    return null;

  })

  /* */

  a.ready.then( function()
  {
    test.case = 'stdio inherit, sync, collecting, verbosity and piping off';

    let o =
    {
      execPath : testAppPath,
      mode : 'fork',
      stdio : 'inherit',
      sync : 1,
      deasync : 1,
      verbosity : 0,
      outputCollecting : 0,
      outputPiping : 0
    }

    a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

    let o2 =
    {
      execPath : testAppPath2,
      mode : 'fork',
      stdio : 'pipe',
      sync : 1,
      deasync : 1,
      verbosity : 0,
      outputPiping : 1,
      outputPrefixing : 1,
      outputCollecting : 1,
    }
    var returned = test.shouldThrowErrorSync( () => _.process.start( o2 ) )

    test.is( _.errIs( returned ) );
    test.is( _.strHas( returned.message, 'Process returned exit code' ) )
    test.is( _.strHas( returned.message, 'Launched as' ) )
    test.is( _.strHas( returned.message, 'Stderr' ) )
    test.is( _.strHas( returned.message, 'Error message from child' ) )

    test.is( _.strHas( o2.output, 'Process returned exit code' ) )
    test.is( _.strHas( o2.output, 'Launched as' ) )
    test.is( !_.strHas( o2.output, 'Stderr' ) )
    test.is( _.strHas( o2.output, 'Error message from child' ) )

    test.notIdentical( o2.exitCode, 0 );

    return null;

  })

  /* */

  return a.ready;

  /* - */

  function program1()
  {
    throw new Error( 'Error message from child' )
  }

  function program2()
  {
    let _ = require( toolsPath );
    _.include( 'wFiles' );
    _.include( 'wProcess' );

    let op = _.fileProvider.fileRead
    ({
      filePath : _.path.join( __dirname, 'op.json'),
      encoding : 'json'
    });

    _.process.start( op );

  }

}

//

// --
// sync
// --

function startSync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );

  let o3 =
  {
    outputPiping : 1,
    outputCollecting : 1,
    applyingExitCode : 0,
    throwingExitCode : 1,
    sync : 1
  }

  /* */

  var expectedOutput = programPath + '\n';
  var o2;

  /* - */

  test.case = 'mode : spawn';
  o2 =
  {
    execPath :  'node ' + programPath,
    mode : 'spawn',
    stdio : 'pipe'
  }

  /* mode : spawn, stdio : pipe */

  var options = _.mapSupplement( {}, o2, o3 );
  _.process.start( options );
  debugger;
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, expectedOutput );

  /* mode : spawn, stdio : ignore */

  o2.stdio = 'ignore';
  o2.outputCollecting = 0;
  o2.outputPiping = 0;

  var options = _.mapSupplement( {}, o2, o3 );
  _.process.start( options )
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, null );

  /* */

  test.case = 'mode : shell';
  o2 =
  {
    execPath :  'node ' + programPath,
    mode : 'shell',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  _.process.start( options )
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, expectedOutput );

  /* mode : shell, stdio : ignore */

  o2.stdio = 'ignore'
  o2.outputCollecting = 0;
  o2.outputPiping = 0;

  var options = _.mapSupplement( {}, o2, o3 );
  _.process.start( options )
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, null );

  /* */

  test.case = 'shell, timeOut';
  o2 =
  {
    execPath :  'node ' + programPath + ' loop : 1',
    mode : 'shell',
    stdio : 'pipe',
    timeOut : 2*context.t1
  }

  var options = _.mapSupplement( {}, o2, o3 );
  test.shouldThrowErrorSync( () => _.process.start( options ) );

  /* */

  test.case = 'spawn, return good code';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 0',
    mode : 'spawn',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  test.mustNotThrowError( () => _.process.start( options ) )
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );

  /* */

  test.case = 'spawn, return ext code 1';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 1',
    mode : 'spawn',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  test.shouldThrowErrorSync( () => _.process.start( options ) );
  test.identical( options.exitCode, 1 );

  /* */

  test.case = 'spawn, return ext code 2';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 2',
    mode : 'spawn',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  test.shouldThrowErrorSync( () => _.process.start( options ) );
  test.identical( options.exitCode, 2 );

  /* */

  test.case = 'shell, return good code';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 0',
    mode : 'shell',
    stdio : 'pipe'
  }

  var options = _.mapSupplement( {}, o2, o3 );
  test.mustNotThrowError( () => _.process.start( options ) )
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );

  /* */

  test.case = 'shell, return bad code';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 1',
    mode : 'shell',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  test.shouldThrowErrorSync( () => _.process.start( options ) )
  test.identical( options.exitCode, 1 );

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    let process = _global_.process;

    _.include( 'wProcess' );
    _.include( 'wStringsExtra' )

    process.removeAllListeners( 'SIGINT' );
    process.removeAllListeners( 'SIGTERM' );
    process.removeAllListeners( 'exit' );

    var args = _.process.args();

    if( args.map.exitWithCode )
    process.exit( args.map.exitWithCode )

    if( args.map.loop )
    _.time.out( 5000 )

    console.log( __filename );
  }
}

//

function startSyncDeasync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let o3 =
  {
    outputPiping : 1,
    outputCollecting : 1,
    applyingExitCode : 0,
    throwingExitCode : 1,
    sync : 1,
    deasync : 1
  }
  let expectedOutput = programPath + '\n';
  let o2;

  /* - */

  test.case = 'mode : fork';
  o2 =
  {
    execPath : programPath,
    mode : 'fork',
    stdio : 'pipe'
  }

  /* mode : spawn, stdio : pipe */

  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, expectedOutput );

  /* mode : fork, stdio : ignore */

  o2.stdio = 'ignore';
  o2.outputCollecting = 0;
  o2.outputPiping = 0;

  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, null );

  /* */

  test.case = 'mode : spawn';
  o2 =
  {
    execPath :  'node ' + programPath,
    mode : 'spawn',
    stdio : 'pipe'
  }

  /* mode : spawn, stdio : pipe */

  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, expectedOutput );

  /* mode : spawn, stdio : ignore */

  o2.stdio = 'ignore';
  o2.outputCollecting = 0;
  o2.outputPiping = 0;

  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, null );

  /* */

  test.case = 'mode : shell';
  o2 =
  {
    execPath :  'node ' + programPath,
    mode : 'shell',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, expectedOutput );

  /* mode : shell, stdio : ignore */

  o2.stdio = 'ignore'
  o2.outputCollecting = 0;
  o2.outputPiping = 0;

  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );
  test.identical( options.output, null );

  /* */

  test.case = 'shell, timeOut';
  o2 =
  {
    execPath :  'node ' + programPath + ' loop : 1',
    mode : 'shell',
    stdio : 'pipe',
    timeOut : 2*context.t1,
  }

  var options = _.mapSupplement( {}, o2, o3 );
  test.shouldThrowErrorSync( () => _.process.start( options ) );

  /* */

  test.case = 'spawn, return good code';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 0',
    mode : 'spawn',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );

  /* */

  test.case = 'spawn, return bad code';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 1',
    mode : 'spawn',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  test.shouldThrowErrorSync( () => _.process.start( options ) )
  test.identical( options.exitCode, 1 );

  /* */

  test.case = 'shell, return good code';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 0',
    mode : 'shell',
    stdio : 'pipe'
  }

  var options = _.mapSupplement( {}, o2, o3 );
  var returned = _.process.start( options );
  test.is( returned === options );
  test.identical( returned.process.constructor.name, 'ChildProcess' );
  test.identical( options.exitCode, 0 );
  test.identical( o.exitSignal, null );
  test.identical( o.exitReason, 'normal' );
  test.identical( o.ended, true );
  test.identical( o.state, 'terminated' );

  /* */

  test.case = 'shell, return bad code';
  o2 =
  {
    execPath :  'node ' + programPath + ' exitWithCode : 1',
    mode : 'shell',
    stdio : 'pipe'
  }
  var options = _.mapSupplement( {}, o2, o3 );
  test.shouldThrowErrorSync( () => _.process.start( options ) )
  test.identical( options.exitCode, 1 );

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    let process = _global_.process;

    _.include( 'wProcess' );
    _.include( 'wStringsExtra' )

    process.removeAllListeners( 'SIGINT' );
    process.removeAllListeners( 'SIGTERM' );
    process.removeAllListeners( 'exit' );

    var args = _.process.args();

    if( args.map.exitWithCode )
    process.exit( args.map.exitWithCode )

    if( args.map.loop )
    _.time.out( 5000 )

    console.log( __filename );
  }

}

//

function startSpawnSyncDeasync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( testApp ) );

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( op )
    {
      test.identical( op.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return op;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 1,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned, o );
    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( op )
    {
      test.identical( op.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return op;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned, o );
    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );
    return returned;
  })

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

startSpawnSyncDeasync.timeOut = 15000;

//

function startSpawnSyncDeasyncThrowing( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( testApp );

  /* */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    return test.shouldThrowErrorAsync( returned );
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 1,
      deasync : 0
    }
    test.shouldThrowErrorSync( () =>  _.process.start( o ) );
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    return test.shouldThrowErrorAsync( returned );
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'spawn',
      sync : 1,
      deasync : 1
    }
    test.shouldThrowErrorSync( () =>  _.process.start( o ) );
    return null;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    throw new Error( 'Test error' );
  }
}

startSpawnSyncDeasyncThrowing.timeOut = 15000;

//

function startShellSyncDeasync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( testApp ) );

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( op )
    {
      test.identical( op.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return op;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 1,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned, o );
    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( op )
    {
      test.identical( op.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return op;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned, o );
    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );
    return returned;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

startShellSyncDeasync.timeOut = 15000;

//

function startShellSyncDeasyncThrowing( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( testApp );

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    return test.shouldThrowErrorAsync( returned );
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 1,
      deasync : 0
    }
    test.shouldThrowErrorSync( () =>  _.process.start( o ) );
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    return test.shouldThrowErrorAsync( returned );
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : 'node ' + programPath,
      mode : 'shell',
      sync : 1,
      deasync : 1
    }
    test.shouldThrowErrorSync( () =>  _.process.start( o ) );
    return null;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    throw new Error( 'Test error' );
  }

}

startShellSyncDeasyncThrowing.timeOut = 15000;

//

function startForkSyncDeasync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( testApp );

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( op )
    {
      test.identical( op.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return op;
    })
    return returned;
  })

  /*  */

  if( Config.debug )
  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 1,
      deasync : 0
    }
    test.shouldThrowErrorSync( () => _.process.start( o ) )
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( op )
    {
      test.identical( op.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return op;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned, o );
    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );
    return returned;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

startForkSyncDeasync.timeOut = 15000;

//

function startForkSyncDeasyncThrowing( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( testApp );

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    return test.shouldThrowErrorAsync( returned );
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 1,
      deasync : 0
    }
    test.shouldThrowErrorSync( () =>  _.process.start( o ) );
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    return test.shouldThrowErrorAsync( returned );
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : programPath,
      mode : 'fork',
      sync : 1,
      deasync : 1
    }
    test.shouldThrowErrorSync( () =>  _.process.start( o ) );
    return null;
  })

  /*  */

  return a.ready;

  function testApp()
  {
    throw new Error( 'Test error' );
  }
}

startForkSyncDeasyncThrowing.timeOut = 15000;

//

/* qqq2 for Yevhen : introduce subroutine for modes */
function startMultipleSyncDeasync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( testApp ) );

/*

qqq for Yevhen : should check all that

test.identical( o.exitCode, 0 );
test.identical( o.exitSignal, null );
test.identical( o.exitReason, 'normal' );
test.identical( o.ended, true );
test.identical( o.state, 'terminated' );

*/

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( result )
    {
      // debugger;
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 1,
      // returningOptionsArray : 1,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 1,
      // returningOptionsArray : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned.exitCode, 0 )
    test.identical( returned.exitSignal, null );
    test.identical( returned.exitReason, 'normal' );
    test.identical( returned.ended, true );
    test.identical( returned.state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 1,
      // returningOptionsArray : 1,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 1,
      // returningOptionsArray : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned.exitCode, 0 )
    test.identical( returned.exitSignal, null );
    test.identical( returned.exitReason, 'normal' );
    test.identical( returned.ended, true );
    test.identical( returned.state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 1,
      // returningOptionsArray : 1,
      deasync : 0
    }
    test.shouldThrowErrorSync( () => _.process.start( o ) );
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 1,
      // returningOptionsArray : 0,
      deasync : 0
    }
    test.shouldThrowErrorSync( () => _.process.start( o ) );
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      ttest.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );
  
      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:0'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 0 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 1,
      // returningOptionsArray : 1,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned.runs.length, 2 )
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 1,
      // returningOptionsArray : 1,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 )
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 1,
      // returningOptionsArray : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned.exitCode, 0 )
    test.identical( returned.exitSignal, null );
    test.identical( returned.exitReason, 'normal' );
    test.identical( returned.ended, true );
    test.identical( returned.state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:0'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 1,
      // returningOptionsArray : 0,
      deasync : 0
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( returned.exitCode, 0 );
    test.identical( returned.exitSignal, null );
    test.identical( returned.exitReason, 'normal' );
    test.identical( returned.ended, true );
    test.identical( returned.state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return null;
  })


  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:0,desync:1'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 0,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    test.identical( returned.resourcesCount(), 1 );
    returned.then( function( result )
    {
      test.is( result === o );
      test.identical( o.runs.length, 2 );
      test.identical( o.runs[ 0 ].exitCode, 0 );
      test.identical( o.runs[ 0 ].exitSignal, null );
      test.identical( o.runs[ 0 ].exitReason, 'normal' );
      test.identical( o.runs[ 0 ].ended, true );
      test.identical( o.runs[ 0 ].state, 'terminated' );

      test.identical( o.runs[ 1 ].exitCode, 0 );
      test.identical( o.runs[ 1 ].exitSignal, null );
      test.identical( o.runs[ 1 ].exitReason, 'normal' );
      test.identical( o.runs[ 1 ].ended, true );
      test.identical( o.runs[ 1 ].state, 'terminated' );

      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      return result;
    })
    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'shell',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : [ 'node ' + programPath, 'node ' + programPath ],
      mode : 'spawn',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  a.ready.then( () =>
  {
    test.case = 'sync:1,desync:1'
    let o =
    {
      execPath : [ programPath, programPath ],
      mode : 'fork',
      sync : 1,
      deasync : 1
    }
    var returned = _.process.start( o );
    test.is( !_.consequenceIs( returned ) );
    test.is( returned === o );
    test.identical( o.runs.length, 2 );
    test.identical( o.runs[ 0 ].exitCode, 0 );
    test.identical( o.runs[ 0 ].exitSignal, null );
    test.identical( o.runs[ 0 ].exitReason, 'normal' );
    test.identical( o.runs[ 0 ].ended, true );
    test.identical( o.runs[ 0 ].state, 'terminated' );

    test.identical( o.runs[ 1 ].exitCode, 0 );
    test.identical( o.runs[ 1 ].exitSignal, null );
    test.identical( o.runs[ 1 ].exitReason, 'normal' );
    test.identical( o.runs[ 1 ].ended, true );
    test.identical( o.runs[ 1 ].state, 'terminated' );

    test.identical( o.exitCode, 0 );
    test.identical( o.exitSignal, null );
    test.identical( o.exitReason, 'normal' );
    test.identical( o.ended, true );
    test.identical( o.state, 'terminated' );

    return returned;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) )
  }
}

// --
// arguments
// --

function startWithoutExecPath( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( testApp ) );
  let counter = 0;
  let time = 0;
  let filePath = a.path.nativize( a.abs( a.routinePath, 'file.txt' ) );

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single';
    time = _.time.now();
    return null;
  })

  let singleOption =
  {
    args : [ 'node', programPath, '1000' ],
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  _.process.start( singleOption )
  .then( ( arg ) =>
  {
    test.identical( arg.exitCode, 0 );
    test.identical( arg.exitSignal, null );
    test.identical( arg.exitReason, 'normal' );
    test.identical( arg.ended, true );
    test.identical( arg.state, 'terminated' );
    test.is( singleOption === arg );
    test.is( _.strHas( arg.output, 'begin 1000' ) );
    test.is( _.strHas( arg.output, 'end 1000' ) );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );
    counter += 1;
    return null;
  });

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    var ended = 0;
    var fs = require( 'fs' );
    var path = require( 'path' );
    var filePath = path.join( __dirname, 'file.txt' );
    console.log( 'begin', process.argv.slice( 2 ).join( ', ' ) );
    var time = parseInt( process.argv[ 2 ] );
    if( isNaN( time ) )
    throw new Error( 'Expects number' );

    setTimeout( end, time );
    function end()
    {
      ended = 1;
      fs.writeFileSync( filePath, 'written by ' + process.argv[ 2 ] );
      console.log( 'end', process.argv.slice( 2 ).join( ', ' ) );
    }

    setTimeout( periodic, 50 );
    function periodic()
    {
      console.log( 'tick', process.argv.slice( 2 ).join( ', ' ) );
      if( !ended )
      setTimeout( periodic, 50 );
    }
  }
}

//

function startArgsOption( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( testApp ) );

  /* */

  a.ready.then( () =>
  {
    test.case = 'args option as array, source args array should not be changed'
    var args = [ 'arg1', 'arg2' ];
    var startOptions =
    {
      execPath : 'node ' + programPath,
      outputCollecting : 1,
      args,
      mode : 'spawn',
    }

    let con = _.process.start( startOptions )

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( op.args, [ programPath, 'arg1', 'arg2' ] );
      test.identical( _.strCount( op.output, `[ 'arg1', 'arg2' ]` ), 1 );
      test.identical( startOptions.args, op.args );
      test.identical( args, [ 'arg1', 'arg2' ] );
      return null;
    })

    return con;
  })

  /* */

  a.ready.then( () =>
  {
    test.case = 'args option as string'
    var args = 'arg1'
    var startOptions =
    {
      execPath : 'node ' + programPath,
      outputCollecting : 1,
      args,
      mode : 'spawn',
    }

    let con = _.process.start( startOptions )

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( op.args, [ programPath, 'arg1' ] );
      test.identical( _.strCount( op.output, 'arg1' ), 1 );
      test.identical( startOptions.args, op.args );
      test.identical( args, 'arg1' );
      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

//

/*
qqq for Yevhen : split shellArgumentsParsing and similar test routine by mode
*/

/* qqq for Yevhen : try to introduce subroutine for modes */

function startArgumentsParsing( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPathNoSpace = a.path.nativize( a.program({ routine : testApp, dirPath : a.abs( 'noSpace' ) }) );
  let testAppPathSpace = a.path.nativize( a.program({ routine : testApp, dirPath : a.abs( 'with space' ) }) );

  /* for combination:
      path to exe file : [ with space, without space ]
      execPath : [ has arguments, only path to exe file ]
      args : [ has arguments, empty ]
      mode : [ 'fork', 'spawn', 'shell' ]
  */

  /* - */

  a.ready

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : has arguments' 'args has arguments' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1 "third arg"',
      args : [ '\'fourth arg\'',  `"fifth" arg` ],
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : has arguments' 'args has arguments' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathNoSpace ) + ' firstArg secondArg:1 "third arg"',
      args : [ '\'fourth arg\'',  `"fifth" arg` ],
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args has arguments' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ),
      args : [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', `"fifth" arg` ],
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : only path' 'args has arguments' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathNoSpace ),
      args : [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', `"fifth" arg` ],
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : has arguments' 'args: empty' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1 "third arg" \'fourth arg\' `"fifth" arg`',
      args : null,
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" "fourth arg" "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', 'fourth arg', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : has arguments' 'args: empty' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathNoSpace ) + ' firstArg secondArg:1 "third arg" \'fourth arg\' `"fifth" arg`',
      args : null,
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" "fourth arg" "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', 'fourth arg', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args: empty' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ),
      args : null,
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : only path' 'args: empty' 'fork'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathNoSpace ),
      args : null,
      ipc : 1,
      mode : 'fork',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [] )

      return null;
    })

    return con;
  })

  /* - */

  /* - end of fork - */ /* qqq for Yevhen : split test routine by modes */

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : has arguments' 'args has arguments' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1 "third arg"',
      args : [ '\'fourth arg\'',  `"fifth" arg` ],
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : has arguments' 'args has arguments' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ) + ' firstArg secondArg:1 "third arg"',
      args : [ '\'fourth arg\'',  `"fifth" arg` ],
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args has arguments' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', `"fifth" arg` ],
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : only path' 'args has arguments' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ),
      args : [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', `"fifth" arg` ],
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : has arguments' 'args: empty' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1 "third arg" \'fourth arg\' `"fifth" arg`',
      args : null,
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" "fourth arg" "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', 'fourth arg', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : has arguments' 'args: empty' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ) + ' firstArg secondArg:1 "third arg" \'fourth arg\' `"fifth" arg`',
      args : null,
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" "fourth arg" "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', 'fourth arg', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args: empty' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : null,
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : only path' 'args: empty' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ),
      args : null,
      ipc : 1,
      mode : 'spawn',
      outputPiping : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : has arguments' 'args has arguments' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1 "third arg"',
      args : [ '\'fourth arg\'',  `"fifth" arg` ],
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', '\'fourth arg\'', '"fifth" arg' ] )
      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : has arguments' 'args has arguments' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ) + ' firstArg secondArg:1 "third arg"',
      args : [ '\'fourth arg\'',  `"fifth" arg` ],
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args has arguments' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', `"fifth" arg` ],
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) );
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } );
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', '"fifth" arg' ] );
      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : only path' 'args has arguments' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ),
      args : [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', `"fifth" arg` ],
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" 'fourth arg' "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"', '\'fourth arg\'', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : has arguments' 'args: empty' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ) + ' firstArg secondArg:1 "third arg" \'fourth arg\' \'"fifth" arg\'',
      args : null,
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : `1 "third arg" "fourth arg" "fifth" arg` } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', 'fourth arg', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : has arguments' 'args: empty' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ) + ' firstArg secondArg:1 "third arg" \'fourth arg\' \'"fifth" arg\'',
      args : null,
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, { secondArg : '1 "third arg" "fourth arg" "fifth" arg' } )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', 'third arg', 'fourth arg', '"fifth" arg' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args: empty' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : null,
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : without space' 'execPATH : only path' 'args: empty' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathNoSpace ),
      args : null,
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathNoSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [] )

      return null;
    })

    return con;
  })

  /* */

  /* special case from willbe */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args: willbe args' 'fork'`

    debugger;
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ),
      args : '.imply v:1 ; .each . .resources.list about::name',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    let op;
    o.process.on( 'message', ( e ) => { op = e } )

    con.then( () =>
    {
      debugger;
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) );
      test.identical( op.map, { v : 1 } );
      test.identical( op.scriptArgs, [ '.imply v:1 ; .each . .resources.list about::name' ] );

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args: willbe args' 'spawn'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : '.imply v:1 ; .each . .resources.list about::name',
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { v : 1 } )
      test.identical( op.scriptArgs, [ '.imply v:1 ; .each . .resources.list about::name' ] )

      return null;
    })

    return con;
  })

  /* - */

  .then( () =>
  {
    test.case = `'path to exec : with space' 'execPATH : only path' 'args: willbe args' 'shell'`

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : '.imply v:1 ; .each . .resources.list about::name',
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { v : 1 } )
      test.identical( op.scriptArgs, [ '.imply v:1 ; .each . .resources.list about::name' ] )

      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wStringsExtra' )
    debugger;
    var args = _.process.args();
    if( process.send )
    process.send( args );
    else
    console.log( JSON.stringify( args ) );
  }

}

//

function startArgumentsParsingNonTrivial( test )
{
  let context = this;

  let a = context.assetFor( test, false );

  let testAppPathNoSpace = a.path.nativize( a.program({ routine : testApp, dirPath : a.abs( 'noSpace' ) }) );
  let testAppPathSpace = a.path.nativize( a.program({ routine : testApp, dirPath : a.abs( 'with space' ) }) );

  /*

  execPath : '"/dir with space/app.exe" `firstArg secondArg ":" 1` "third arg" \'fourth arg\'  `"fifth" arg`,
  args : '"some arg"'
  mode : 'spawn'
  ->
  execPath : '/dir with space/app.exe'
  args : [ 'firstArg secondArg ":" 1', 'third arg', 'fourth arg', '"fifth" arg', '"some arg"' ],

  =

  execPath : '"/dir with space/app.exe" firstArg secondArg:1',
  args : '"third arg"',
  ->
  execPath : '/dir with space/app.exe'
  args : [ 'firstArg', 'secondArg:1', '"third arg"' ]

  =

  execPath : '"first arg"'
  ->
  execPath : 'first arg'
  args : []

  =

  args : '"first arg"'
  ->
  execPath : 'first arg'
  args : []

  =

  args : [ '"first arg"', 'second arg' ]
  ->
  execPath : 'first arg'
  args : [ 'second arg' ]

  =

  args : [ '"', 'first', 'arg', '"' ]
  ->
  execPath : '"'
  args : [ 'first', 'arg', '"' ]

  =

  args : [ '', 'first', 'arg', '"' ]
  ->
  execPath : ''
  args : [ 'first', 'arg', '"' ]

  =

  args : [ '"', '"', 'first', 'arg', '"' ]
  ->
  execPath : '"'
  args : [ '"', 'first', 'arg', '"' ]

  */

  a.ready

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' `firstArg secondArg ":" 1` "third arg" \'fourth arg\'  `"fifth" arg`',
      args : '"some arg"',
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.execPath, 'node' );
      test.identical( o.args, [ testAppPathSpace, 'firstArg secondArg ":" 1', 'third arg', 'fourth arg', '"fifth" arg', '"some arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'firstArg secondArg ":" 1', 'third arg', 'fourth arg', '"fifth" arg', '"some arg"' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ` 'firstArg secondArg \":\" 1' "third arg" 'fourth arg'  '\"fifth\" arg'`,
      args : '"some arg"',
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.execPath, 'node' );
      test.identical( o.args, [ _.strQuote( testAppPathSpace ), `'firstArg secondArg \":\" 1'`, `"third arg"`, `'fourth arg'`, `'\"fifth\" arg'`, '"some arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      if( process.platform === 'win32' )
      test.identical( op.scriptArgs, [ `'firstArg`, `secondArg`, ':', `1'`, 'third arg', `'fourth`, `arg'`, `'fifth`, `arg'`, '"some arg"' ] )
      else
      test.identical( op.scriptArgs, [ 'firstArg secondArg ":" 1', 'third arg', 'fourth arg', '"fifth" arg', '"some arg"' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' `firstArg secondArg ":" 1` "third arg" \'fourth arg\'  `"fifth" arg`',
      args : '"some arg"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.execPath, testAppPathSpace );
      test.identical( o.args, [ 'firstArg secondArg ":" 1', 'third arg', 'fourth arg', '"fifth" arg', '"some arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'firstArg secondArg ":" 1', 'third arg', 'fourth arg', '"fifth" arg', '"some arg"' ] )

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1',
      args : '"third arg"',
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.execPath, 'node' );
      test.identical( o.args, [ testAppPathSpace, 'firstArg', 'secondArg:1', '"third arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : '1 "third arg"' } )
      test.identical( op.subject, 'firstArg' )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1',
      args : '"third arg"',
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.execPath, 'node' );
      test.identical( o.args, [ _.strQuote( testAppPathSpace ), 'firstArg', 'secondArg:1', '"third arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : '1 "third arg"' } )
      test.identical( op.subject, 'firstArg' )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' firstArg secondArg:1',
      args : '"third arg"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.execPath, testAppPathSpace );
      test.identical( o.args, [ 'firstArg', 'secondArg:1', '"third arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { secondArg : '1 "third arg"' } )
      test.identical( op.subject, 'firstArg' )
      test.identical( op.scriptArgs, [ 'firstArg', 'secondArg:1', '"third arg"' ] )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : '"first arg"',
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 0,
      ready : con
    }
    _.process.start( o );

    con.finally( ( err, op ) =>
    {
      test.is( !!err );
      test.is( _.strHas( err.message, 'first arg' ) )
      test.identical( o.execPath, 'first arg' );
      test.identical( o.args, [] );

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      args : '"first arg"',
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 0,
      ready : con
    }
    _.process.start( o );

    con.finally( ( err, op ) =>
    {
      test.is( !!err );
      test.is( _.strHas( err.message, 'first arg' ) )
      test.identical( o.execPath, 'first arg' );
      test.identical( o.args, [] );

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      args : [ '"first arg"', 'second arg' ],
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 0,
      ready : con
    }
    _.process.start( o );

    con.finally( ( err, op ) =>
    {
      test.is( !!err );
      test.is( _.strHas( err.message, 'first arg' ) )
      test.identical( o.execPath, 'first arg' );
      test.identical( o.args, [ 'second arg' ] );

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      args : [ '"', 'first', 'arg', '"' ],
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 0,
      ready : con
    }
    _.process.start( o );

    con.finally( ( err, op ) =>
    {
      test.is( !!err );
      test.is( _.strHas( err.message, '"' ) )
      test.identical( o.execPath, '"' );
      test.identical( o.args, [ 'first', 'arg', '"' ] );

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      args : [ '', 'first', 'arg', '"' ],
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 0,
      ready : con
    }
    _.process.start( o );

    con.finally( ( err, op ) =>
    {
      test.is( !!err );
      test.identical( o.execPath, '' );
      test.identical( o.args, [ 'first', 'arg', '"' ] );

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      args : [ '"', '"', 'first', 'arg', '"' ],
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 0,
      ready : con
    }
    _.process.start( o );

    con.finally( ( err, op ) =>
    {
      test.is( !!err );
      test.is( _.strHas( err.message, `spawn " ENOENT` ) );
      test.identical( o.execPath, '"' );
      test.identical( o.args, [ '"', 'first', 'arg', '"' ] );

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'no execPath, empty args'

    let con = new _.Consequence().take( null );
    let o =
    {
      args : [],
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 0,
      ready : con
    }

    _.process.start( o );

    return test.shouldThrowErrorAsync( con );
  })

  /*  */

  .then( () =>
  {
    test.case = 'args in execPath and args options'

    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ` "path/key3":'val3'`,
      args : [],
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.execPath, testAppPathSpace );
      test.identical( o.args, [ `"path/key3":'val3'` ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { 'path/key3' : 'val3' } )
      test.identical( op.subject, '' )
      test.identical( op.scriptArgs, [ `"path/key3":'val3'` ] )

      return null;
    })

    return con;
  })

  /*  */

  return a.ready;


  /**/

  function testApp()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wStringsExtra' )
    var args = _.process.args();
    console.log( JSON.stringify( args ) );
  }
}

//

function startArgumentsNestedQuotes( test )
{
  let context = this;

  let a = context.assetFor( test, false );

  let testAppPathSpace = a.path.nativize( a.program({ routine : testApp, dirPath : a.abs( 'with space' ) }) );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'fork'

    let con = new _.Consequence().take( null );
    let args =
    [
      ` '\'s-s\''  '\"s-d\"'  '\`s-b\`'  `,
      ` "\'d-s\'"  "\"d-d\""  "\`d-b\`"  `,
      ` \`\'b-s\'\`  \`\"b-d\"\`  \`\`b-b\`\` `,
    ]
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' ' + args.join( ' ' ),
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      let scriptArgs =
      [
        `'s-s'`, `"s-d"`, `\`s-b\``,
        `'d-s'`, `"d-d"`, `\`d-b\``,
        `'b-s'`, `"b-d"`, `\`b-b\``,
      ]
      test.identical( op.scriptArgs, scriptArgs )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'fork'

    let con = new _.Consequence().take( null );
    let args =
    [
      ` '\'s-s\''  '\"s-d\"'  '\`s-b\`'  `,
      ` "\'d-s\'"  "\"d-d\""  "\`d-b\`"  `,
      ` \`\'b-s\'\`  \`\"b-d\"\`  \`\`b-b\`\` `,
    ]
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ),
      args : args.slice(),
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, args )

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'spawn'

    let con = new _.Consequence().take( null );
    let args =
    [
      ` '\'s-s\''  '\"s-d\"'  '\`s-b\`'  `,
      ` "\'d-s\'"  "\"d-d\""  "\`d-b\`"  `,
      ` \`\'b-s\'\`  \`\"b-d\"\`  \`\`b-b\`\` `,
    ]
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' ' + args.join( ' ' ),
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      let scriptArgs =
      [
        `'s-s'`, `"s-d"`, `\`s-b\``,
        `'d-s'`, `"d-d"`, `\`d-b\``,
        `'b-s'`, `"b-d"`, `\`b-b\``,
      ]
      test.identical( op.scriptArgs, scriptArgs )

      return null;
    })

    return con;

  })

  /* */

  .then( () =>
  {
    test.case = 'spawn'

    let con = new _.Consequence().take( null );
    let args =
    [
      ` '\'s-s\''  '\"s-d\"'  '\`s-b\`'  `,
      ` "\'d-s\'"  "\"d-d\""  "\`d-b\`"  `,
      ` \`\'b-s\'\`  \`\"b-d\"\`  \`\`b-b\`\` `,
    ]
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : args.slice(),
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, args )

      return null;
    })

    return con;

  })

  /* */

  .then( () =>
  {
    test.case = 'shell'
    /*
     This case shows how shell is interpreting backquote on different platforms.
     It can't be used for arguments wrapping on linux/mac:
     https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html
    */

    let con = new _.Consequence().take( null );
    let args =
    [
      ` '\'s-s\''  '\"s-d\"'  '\`s-b\`'  `,
      ` "\'d-s\'"  "\"d-d\""  "\`d-b\`"  `,
      ` \`\'b-s\'\`  \`\"b-d\"\`  \`\`b-b\`\` `,
    ]
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' ' + args.join( ' ' ),
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      if( process.platform === 'win32' )
      {
        let op = JSON.parse( o.output );
        test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
        test.identical( op.map, {} )
        let scriptArgs =
        [
          '\'\'s-s\'\'',
          '\'s-d\'',
          '\'`s-b`\'',
          '\'d-s\'',
          'd-d',
          '`d-b`',
          '`\'b-s\'`',
          '\`b-d`',
          '``b-b``'
        ]
        test.identical( op.scriptArgs, scriptArgs )
      }
      else
      {
        test.identical( _.strCount( o.output, 'not found' ), 3 );
      }

      return null;
    })

    return con;
  })

  /* */

  .then( () =>
  {
    test.case = 'shell'

    let con = new _.Consequence().take( null );
    let args =
    [
      ` '\'s-s\''  '\"s-d\"'  '\`s-b\`'  `,
      ` "\'d-s\'"  "\"d-d\""  "\`d-b\`"  `,
      ` \`\'b-s\'\`  \`\"b-d\"\`  \`\`b-b\`\` `,
    ]
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ),
      args : args.slice(),
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, args )

      return null;
    })

    return con;
  })

  /* */

  return a.ready;

  /**/

  function testApp()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wStringsExtra' )
    var args = _.process.args();
    console.log( JSON.stringify( args ) );
  }
}

//

function startExecPathQuotesClosing( test )
{
  let context = this;

  let a = context.assetFor( test, false );

  let testAppPathSpace = a.path.nativize( a.path.normalize( a.program({ routine : testApp, dirPath : a.abs( 'with space' ) }) ) );

  /* */

  a.ready

  testcase( 'quoted arg' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' "arg"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' arg' );
      test.identical( o.args, [ 'arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' "arg"',
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, 'node ' + testAppPathSpace + ' arg' );
      test.identical( o.args, [ testAppPathSpace, 'arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' "arg"',
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, 'node ' + _.strQuote( testAppPathSpace ) + ' "arg"' );
      test.identical( o.args, [ _.strQuote( testAppPathSpace ), '"arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg' ] )

      return null;
    })

    return con;
  })

  /* */

  testcase( 'unquoted arg' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' arg',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' arg' );
      test.identical( o.args, [ 'arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' arg',
      mode : 'spawn',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, 'node ' + testAppPathSpace + ' arg' );
      test.identical( o.args, [ testAppPathSpace, 'arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' arg',
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, 'node ' + _.strQuote( testAppPathSpace ) + ' arg' );
      test.identical( o.args, [ _.strQuote( testAppPathSpace ), 'arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg' ] )

      return null;
    })

    return con;
  })

  /*  */

  testcase( 'single quote' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' " arg',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' " arg' );
      test.identical( o.args, [ '"', 'arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ '"', 'arg' ] )

      return null;
    })

    return con;
  })

  /*  */

  testcase( 'single quote' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' " arg',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace+ ' " arg' );
      test.identical( o.args, [ '"', 'arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ '"', 'arg' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' arg "',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' arg "' );
      test.identical( o.args, [ 'arg', '"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg', '"' ] )

      return null;
    })

    return con;
  })

  /* */

  testcase( 'arg starts with quote' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' "arg',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) );
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' "arg"arg',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    return test.mustNotThrowError( _.process.start( o ) );
  })

  /* */

  testcase( 'arg ends with quote' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' arg"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    // _.process.start( o )

    // con.then( () =>
    // {
    //   test.identical( o.exitCode, 0 );
    //   test.identical( o.exitSignal, null );
    //   test.identical( o.exitReason, 'normal' );
    //   test.identical( o.ended, true );
    //   test.identical( o.state, 'terminated' );
    //   test.identical( o.fullExecPath, testAppPathSpace + ' arg"' );
    //   test.identical( o.args, [ 'arg"' ] );
    //   let op = JSON.parse( o.output );
    //   test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
    //   test.identical( op.map, {} )
    //   test.identical( op.scriptArgs, [ 'arg"' ] )

    //   return null;
    // })

    return test.shouldThrowErrorAsync( _.process.start( o ) );
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' arg"arg"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o )

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' arg"arg"' );
      test.identical( o.args, [ 'arg"arg"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg"arg"' ] )

      return null;
    })

    return con;
  })

  /* */

  testcase( 'quoted with different symbols' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ` "arg'`,
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) );
  })

  /* */

  testcase( 'quote as part of arg' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' arg"arg',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    // _.process.start( o );

    // con.then( () =>
    // {
    //   test.identical( o.exitCode, 0 );
    //   test.identical( o.fullExecPath, testAppPathSpace + ' arg"arg' );
    //   test.identical( o.args, [ 'arg"arg' ] );
    //   let op = JSON.parse( o.output );
    //   test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
    //   test.identical( op.map, {} )
    //   test.identical( op.scriptArgs, [ 'arg"arg' ] )

    //   return null;
    // })

    return test.shouldThrowErrorAsync( _.process.start( o ) );
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' "arg"arg"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' arg"arg' );
      test.identical( o.args, [ 'arg"arg' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, {} )
      test.identical( op.scriptArgs, [ 'arg"arg' ] )

      return null;
    })

    return con;
  })

  /* */

  testcase( 'option arg with quoted value' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' option : "value"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' option : value' );
      test.identical( o.args, [ 'option', ':', 'value' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { option : 'value' } )
      test.identical( op.scriptArgs, [ 'option', ':', 'value' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' option:"value with space"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' option:"value with space"' );
      test.identical( o.args, [ 'option:"value with space"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { option : 'value with space' } )
      test.identical( op.scriptArgs, [ 'option:"value with space"' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' option : "value with space"',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' option : value with space' );
      test.identical( o.args, [ 'option', ':', 'value with space' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { option : 'value with space' } )
      test.identical( op.scriptArgs, [ 'option', ':', 'value with space' ] )

      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' option:"value',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }

    return test.shouldThrowErrorAsync( _.process.start( o ) );
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' "option: "value""',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' option: "value"' );
      test.identical( o.args, [ 'option: "value"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { option : 'value' } )
      test.identical( op.scriptArgs, [ 'option: "value"' ] )
      return null;
    })

    return con;
  })

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' option : "value',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) );
  })

  /* */

  testcase( 'double quoted with space inside, same quotes' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' "option: "value with space""',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' "option: "value with space""' );
      test.identical( o.args, [ '"option: "value', 'with', 'space""' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { option : 'value with space' } )
      test.identical( op.scriptArgs,  [ '"option: "value', 'with', 'space""' ] )

      return null;
    })

    return con
  })

  /* */

  testcase( 'double quoted with space inside, diff quotes' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : _.strQuote( testAppPathSpace ) + ' `option: "value with space"`',
      mode : 'fork',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, testAppPathSpace + ' option: "value with space"' );
      test.identical( o.args, [ 'option: "value with space"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { option : 'value with space' } )
      test.identical( op.scriptArgs, [ 'option: "value with space"' ] )

      return null;
    })

    return con;
  })

  /* */

  testcase( 'escaped quotes, mode shell' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node ' + _.strQuote( testAppPathSpace ) + ' option: \\"value with space\\"',
      mode : 'shell',
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.fullExecPath, 'node ' + _.strQuote( testAppPathSpace ) + ' option: \\"value with space\\"' );
      test.identical( o.args, [ _.strQuote( testAppPathSpace ), 'option:', '\\"value with space\\"' ] );
      let op = JSON.parse( o.output );
      test.identical( op.scriptPath, _.path.normalize( testAppPathSpace ) )
      test.identical( op.map, { option : 'value with space' } )
      test.identical( op.scriptArgs, [ 'option:', '"value', 'with', 'space"' ] )

      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /*  */

  function testcase( src )
  {
    a.ready.then( () =>
    {
      test.case = src;
      return null;
    })
    return a.ready;
  }

  function testApp()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wStringsExtra' )
    var args = _.process.args();
    console.log( JSON.stringify( args ) );
  }
}

//

function startExecPathSeveralCommands( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( app );

  a.ready

  testcase( 'quoted, mode:shell' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node app.js arg1 && node app.js arg2',
      mode : 'shell',
      currentPath : a.routinePath,
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( ( op ) =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( _.strCount( op.output, `[ 'arg1' ]` ), 1 );
      test.identical( _.strCount( op.output, `[ 'arg2' ]` ), 1 );
      return null;
    })

    return con;
  })

  /* - */

  testcase( 'quoted, mode:spawn' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : '"node app.js arg1 && node app.js arg2"',
      mode : 'spawn',
      currentPath : a.routinePath,
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) )
  })

  /* - */

  testcase( 'quoted, mode:fork' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : '"node app.js arg1 && node app.js arg2"',
      mode : 'fork',
      currentPath : a.routinePath,
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) )
  })

  /* -- */

  testcase( 'no quotes, mode:shell' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node app.js arg1 && node app.js arg2',
      mode : 'shell',
      currentPath : a.routinePath,
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( ( op ) =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( _.strCount( op.output, `[ 'arg1' ]` ), 1 );
      test.identical( _.strCount( op.output, `[ 'arg2' ]` ), 1 );
      return null;
    })

    return con;
  })

  /* - */

  testcase( 'no quotes, mode:spawn' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node app.js arg1 && node app.js arg2',
      mode : 'spawn',
      currentPath : a.routinePath,
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    _.process.start( o );

    con.then( ( op ) =>
    {
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( _.strCount( op.output, `[ 'arg1', '&&', 'node', 'app.js', 'arg2' ]` ), 1 );
      return null;
    })

    return con;
  })

  /* - */

  testcase( 'no quotes, mode:fork' )

  .then( () =>
  {
    let con = new _.Consequence().take( null );
    let o =
    {
      execPath : 'node app.js arg1 && node app.js arg2',
      mode : 'fork',
      currentPath : a.routinePath,
      outputPiping : 1,
      outputCollecting : 1,
      ready : con
    }
    return test.shouldThrowErrorAsync( _.process.start( o ) );
  })

  /*  */

  return a.ready;

  /*  */

  function testcase( src )
  {
    a.ready.then( () =>
    {
      test.case = src;
      return null;
    })
    return a.ready;
  }

  function app()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

//

function startExecPathNonTrivialModeShell( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.path.normalize( a.program( app ) ) );

  let shell = _.process.starter
  ({
    mode : 'shell',
    currentPath : a.routinePath,
    outputPiping : 1,
    outputCollecting : 1,
    ready : a.ready
  })

  /* */

  a.ready.then( () =>
  {
    test.open( 'two commands' );
    return null;
  })

  shell( 'node -v && node -v' )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  shell({ execPath : '"node -v && node -v"', throwingExitCode : 0 })
  .then( ( op ) =>
  {
    if( process.platform ==='win32' )
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( _.strCount( op.output, process.version ), 2 );
    }
    else
    {
      test.notIdentical( op.exitCode, 0 );
      test.identical( op.ended, true );
      test.identical( _.strCount( op.output, process.version ), 0 );
    }

    return null;
  })

  shell({ execPath : 'node -v && "node -v"', throwingExitCode : 0 })
  .then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.identical( _.strCount( op.output, process.version ), 1 );
    return null;
  })

  shell({ args : 'node -v && node -v' })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  shell({ args : '"node -v && node -v"' })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  shell({ args : [ 'node -v && node -v' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  shell({ args : [ 'node', '-v', '&&', 'node', '-v' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  shell({ args : [ 'node', '-v', ' && ', 'node', '-v' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  shell({ args : [ 'node -v', '&&', 'node -v' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  a.ready.then( () =>
  {
    test.close( 'two commands' );
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.open( 'argument with space' );
    return null;
  })

  shell( 'node ' + testAppPath + ' arg with space' )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg', 'with', 'space' ]` ), 1 );
    return null;
  })

  shell( 'node ' + testAppPath + ' "arg with space"' )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg with space' ]` ), 1 );
    return null;
  })

  shell({ execPath : 'node ' + testAppPath, args : 'arg with space' })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg with space' ]` ), 1 );
    return null;
  })

  shell({ execPath : 'node ' + testAppPath, args : [ 'arg with space' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg with space' ]` ), 1 );
    return null;
  })

  shell( 'node ' + testAppPath + ' `"quoted arg with space"`' )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.identical( _.strCount( op.output, `[ '\`quoted arg with space\`' ]` ), 1 );
    else
    test.identical( _.strCount( op.output, `not found` ), 1 );
    return null;
  })

  shell( 'node ' + testAppPath + ` \\\`'quoted arg with space'\\\`` )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    // test.identical( _.strCount( op.output, `[ "'quoted arg with space'" ]` ), 1 );
    let args = a.fileProvider.fileRead({ filePath : a.abs( a.routinePath, 'args' ), encoding : 'json' });
    if( process.platform === 'win32' )
    test.identical( args, [ '\\`\'quoted', 'arg', 'with', 'space\'\\`' ] );
    else
    test.identical( args, [ '`quoted arg with space`' ] );
    return null;
  })

  shell( 'node ' + testAppPath + ` '\`quoted arg with space\`'` )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    let args = a.fileProvider.fileRead({ filePath : a.abs( a.routinePath, 'args' ), encoding : 'json' });
    if( process.platform === 'win32' )
    test.identical( args, [ `\'\`quoted`, 'arg', 'with', `space\`\'` ] );
    else
    test.identical( _.strCount( op.output, `[ '\`quoted arg with space\`' ]` ), 1 );
    return null;
  })

  shell({ execPath : 'node ' + testAppPath, args : '"quoted arg with space"' })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ '"quoted arg with space"' ]` ), 1 );
    return null;
  })

  shell({ execPath : 'node ' + testAppPath, args : '`quoted arg with space`' })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ '\`quoted arg with space\`' ]` ), 1 );
    return null;
  })

  a.ready.then( () =>
  {
    test.close( 'argument with space' );
    return null;
  })

  /*  */

  a.ready.then( () =>
  {
    test.open( 'several arguments' );
    return null;
  })

  shell({ execPath : 'node ' + testAppPath + ` arg1 "arg2" "arg 3" "'arg4'"` })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    // test.identical( _.strCount( op.output, `[ 'arg1', 'arg2', 'arg 3', "'arg4'" ]` ), 1 );
    let args = a.fileProvider.fileRead({ filePath : a.abs( a.routinePath, 'args' ), encoding : 'json' });
    test.identical( args, [ 'arg1', 'arg2', 'arg 3', `'arg4'` ] );
    return null;
  })

  shell({ execPath : 'node ' + testAppPath, args : `arg1 "arg2" "arg 3" "'arg4'"` })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    // test.identical( _.strCount( op.output, '[ `arg1 "arg2" "arg 3" "\'arg4\'"` ]' ), 1 );
    let args = a.fileProvider.fileRead({ filePath : a.abs( a.routinePath, 'args' ), encoding : 'json' });
    test.identical( args, [ `arg1 "arg2" "arg 3" "\'arg4\'"` ] );
    return null;
  })

  shell({ execPath : 'node ' + testAppPath, args : [ `arg1`, '"arg2"', `arg 3`, `'arg4'` ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    // test.identical( _.strCount( op.output, `[ 'arg1', '"arg2"', 'arg 3', "'arg4'" ]` ), 1 );
    let args = a.fileProvider.fileRead({ filePath : a.abs( a.routinePath, 'args' ), encoding : 'json' });
    test.identical( args, [ 'arg1', '"arg2"', 'arg 3', `'arg4'` ] );
    return null;
  })

  a.ready.then( () =>
  {
    test.close( 'several arguments' );
    return null;
  })

  /*  */

  shell({ execPath : 'echo', args : [ 'a b', '*', 'c' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, `"a b" "*" "c"` ) );
    else
    test.is( _.strHas( op.output, `a b * c` ) );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ 'a b', '*', 'c' ] )
    test.identical( op.fullExecPath, 'echo "a b" "*" "c"' )
    return null;
  })

  return a.ready;

  /* - */

  function app()
  {
    var fs = require( 'fs' );
    fs.writeFileSync( 'args', JSON.stringify( process.argv.slice( 2 ) ) )
    console.log( process.argv.slice( 2 ) )
  }
}

//

function startArgumentsHandlingTrivial( test )
{
  let context = this;
  let a = context.assetFor( test, false );

  a.fileProvider.fileWrite( a.abs( a.routinePath, 'file' ), 'file' );

  /* */

  let shell = _.process.starter
  ({
    currentPath : a.routinePath,
    mode : 'shell',
    stdio : 'pipe',
    outputPiping : 1,
    outputCollecting : 1,
    ready : a.ready
  })

  /* */

  shell({ execPath : 'echo *' })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, `*` ) );
    else
    test.is( _.strHas( op.output, `file` ) );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ '*' ] )
    test.identical( op.fullExecPath, 'echo *' )
    return null;
  })

  /* */

  return a.ready;
}

//

function startArgumentsHandling( test )
{
  let context = this;
  let a = context.assetFor( test, false );

  a.fileProvider.fileWrite( a.abs( a.routinePath, 'file' ), 'file' );

  /* */

  let shell = _.process.starter
  ({
    currentPath : a.routinePath,
    mode : 'shell',
    stdio : 'pipe',
    outputPiping : 1,
    outputCollecting : 1,
    ready : a.ready
  })

  /* */

  shell({ execPath : 'echo *' })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, `*` ) );
    else
    test.is( _.strHas( op.output, `file` ) );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ '*' ] )
    test.identical( op.fullExecPath, 'echo *' )
    return null;
  })

  /* */

  shell({ execPath : 'echo', args : '*' })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `*` ) );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ '*' ] )
    test.identical( op.fullExecPath, 'echo "*"' )
    return null;
  })

  /* */

  shell( `echo "*"` )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `*` ) );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ '"*"' ] )
    test.identical( op.fullExecPath, 'echo "*"' )

    return null;
  })

  /* */

  shell({ execPath : 'echo "a b" "*" c' })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, `"a b" "*" c` ) );
    else
    test.is( _.strHas( op.output, `a b * c` ) );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ '"a b"', '"*"', 'c' ] )
    test.identical( op.fullExecPath, 'echo "a b" "*" c' )
    return null;
  })

  /* */

  shell({ execPath : 'echo', args : [ 'a b', '*', 'c' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, `"a b" "*" "c"` ) );
    else
    test.is( _.strHas( op.output, `a b * c` ) );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ 'a b', '*', 'c' ] )
    test.identical( op.fullExecPath, 'echo "a b" "*" "c"' )
    return null;
  })

  /* */

  shell( `echo '"*"'` )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, '"*"' ), 1 );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ `'"*"'` ] )
    test.identical( op.fullExecPath, `echo '"*"'` )
    return null;
  })

  /* */

  shell({ execPath : `echo`, args : [ `'"*"'` ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.identical( _.strCount( op.output, `"'\\"*\\"'"` ), 1 );
    else
    test.identical( _.strCount( op.output, '"*"' ), 1 );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ `'"*"'` ] )
    test.identical( op.fullExecPath, `echo "'\\"*\\"'"` )
    return null;
  })

  /* */

  shell( `echo "'*'"` )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `'*'` ), 1 );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ `"'*'"` ] )
    test.identical( op.fullExecPath, `echo "'*'"` )
    return null;
  })

  /* */

  shell({ execPath : `echo`, args : [ `"'*'"` ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `'*'` ), 1 );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ `"'*'"` ] )
    test.identical( op.fullExecPath, `echo "\\"'*'\\""` )
    return null;
  })

  /* */

  shell( 'echo `*`' )
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.identical( _.strCount( op.output, '`*`' ), 1 );
    else
    test.identical( _.strCount( op.output, 'Usage:' ), 1 );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ '`*`' ] )
    test.identical( op.fullExecPath, 'echo `*`' )
    return null;
  })

  /* */

  shell({ execPath : 'echo', args : [ '`*`' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, '`*`' ), 1 );
    test.identical( op.execPath, 'echo' )
    test.identical( op.args, [ '`*`' ] )
    if( process.platform === 'win32' )
    test.identical( op.fullExecPath, 'echo "`*`"' )
    else
    test.identical( op.fullExecPath, 'echo "\\`*\\`"' )
    return null;
  })

  /* */

  shell({ execPath : `node -e "console.log( process.argv.slice( 1 ) )"`, args : [ 'a b c' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `a b c` ) );
    return null;
  })

  /* */

  shell({ execPath : `node -e "console.log( process.argv.slice( 1 ) )"`, args : [ '"a b c"' ] })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `"a b c"` ) );
    test.identical( op.execPath, 'node' )
    test.identical( op.args, [ '-e', '"console.log( process.argv.slice( 1 ) )"', '"a b c"' ] )
    test.identical( op.fullExecPath, 'node -e "console.log( process.argv.slice( 1 ) )" "\\"a b c\\""' )
    return null;
  })

  /* */

  return a.ready;
}

//

function startImportantExecPath( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  var printArguments = 'node -e "console.log( process.argv.slice( 1 ) )"'

  a.fileProvider.fileWrite( a.abs( a.routinePath, 'file' ), 'file' );

  /* */

  let shell = _.process.starter
  ({
    currentPath : a.routinePath,
    mode : 'shell',
    stdio : 'pipe',
    outputPiping : 1,
    outputCollecting : 1,
    ready : a.ready
  })

  /* */

  shell({ execPath : null, args : [ 'node', '-v', '&&', 'node', '-v' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  /* */

  shell({ execPath : 'node', args : [ '-v', '&&', 'node', '-v' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 1 );
    return null;
  })

  /* */

  shell({ execPath : printArguments, args : [ 'a', '&&', 'node', 'b' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `[ 'a', '&&', 'node', 'b' ]` ) )
    return null;
  })

  /* */

  shell({ execPath : 'echo', args : [ '-v', '&&', 'echo', '-v' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, '"-v" "&&" "echo" "-v"' ) )
    else
    test.is( _.strHas( op.output, '-v && echo -v' ) )
    return null;
  })

  /* */

  shell({ execPath : 'node -v && node -v', args : [] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 2 );
    return null;
  })

  /* */

  shell({ execPath : `node -v "&&" node -v`, args : [] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, process.version ), 1 );
    return null;
  })

  /* */

  shell({ execPath : `echo -v "&&" node -v`, args : [] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, '-v "&&" node -v'  ) );
    else
    test.is( _.strHas( op.output, '-v && node -v'  ) );
    return null;
  })

  /* */

  shell({ execPath : null, args : [ 'echo', '*' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.identical( _.strCount( op.output, '*' ), 1 );
    else
    test.identical( _.strCount( op.output, 'file' ), 1 );
    return null;
  })

  /* */

  shell({ execPath : 'echo', args : [ '*' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, '*' ), 1 );
    return null;
  })

  /* */

  shell({ execPath : 'echo *' })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.identical( _.strCount( op.output, '*' ), 1 );
    else
    test.identical( _.strCount( op.output, 'file' ), 1 );
    return null;
  })

  /* */

  shell({ execPath : 'echo "*"' })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, '*' ), 1 );
    return null;
  })

  /* */

  shell({ execPath : null, args : [ printArguments, 'a b' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `[ 'a', 'b' ]` ) );
    return null;
  })

  /* */

  shell({ execPath : printArguments, args : [ 'a b' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `[ 'a b' ]` ) );
    return null;
  })

  /* */

  shell({ execPath : `${printArguments} a b` })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `[ 'a', 'b' ]` ) );
    return null;
  })

  /* */

  shell({ execPath : `${printArguments} "a b"` })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, `[ 'a b' ]` ) );
    return null;
  })

  /* */

  shell({ execPath : null, args : [ 'echo', '"*"' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, '*' ) );
    return null;
  })

  /* */

  shell({ execPath : 'echo', args : [ '"*"' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, '\\"*\\"' ) );
    else
    test.is( _.strHas( op.output, '"*"' ) );
    return null;
  })

  /* */

  shell({ execPath : null, args : [ 'echo', '\\"*\\"' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, '\\"*\\"' ) );
    else
    test.is( _.strHas( op.output, '"*"' ) );
    return null;
  })

  /* */

  shell({ execPath : 'echo "\\"*\\""', args : [] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, '"\\"*\\"' ) );
    else
    test.is( _.strHas( op.output, '"*"' ) );
    return null;
  })

  /* */

  shell({ execPath : 'echo *', args : [ '*' ] })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    {
      test.is( _.strHas( op.output, '*' ) );
      test.is( _.strHas( op.output, '"*"' ) );
    }
    else
    {
      test.is( _.strHas( op.output, 'file' ) );
      test.is( _.strHas( op.output, '*' ) );
    }
    return null;
  })

  /* qqq for Yevhen : separate test routine startImportantExecPathPassingThrough and run it from separate process */
  /* zzz */

  /* */

  shell({ execPath : 'echo', args : null, passingThrough : 1 })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, '"' + process.argv.slice( 2 ).join( '" "' ) + '"' ) );
    else
    test.is( _.strHas( op.output, process.argv.slice( 2 ).join( ' ') ) );
    return null;
  })

  /* */

  shell({ execPath : null, args : [ 'echo' ], passingThrough : 1 })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    test.is( _.strHas( op.output, '"' + process.argv.slice( 2 ).join( '" "' ) + '"' ) );
    else
    test.is( _.strHas( op.output, process.argv.slice( 2 ).join( ' ') ) );
    return null;
  })

  shell({ execPath : 'echo *', args : [ '*' ], passingThrough : 1 })
  .then( function( op )
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    if( process.platform === 'win32' )
    {
      test.is( _.strHas( op.output, '*' ) );
      test.is( _.strHas( op.output, '"*"' ) );
      test.is( _.strHas( op.output, '"' + process.argv.slice( 2 ).join( '" "' ) + '"' ) );
    }
    else
    {
      test.is( _.strHas( op.output, 'file' ) );
      test.is( _.strHas( op.output, '*' ) );
      test.is( _.strHas( op.output, process.argv.slice( 2 ).join( ' ') ) );
    }
    return null;
  })

  return a.ready;
}

startImportantExecPath.description =
`
exec paths with special chars
`

//

function startImportantExecPathPassingThrough( test )
{
  let context = this;
  let a = test.assetFor( false );

  /* */

  let shell = _.process.starter
  ({
    currentPath : a.routinePath,
    mode : 'shell',
    stdio : 'pipe',
    outputPiping : 1,
    outputCollecting : 1,
    ready : a.ready
  })

//   /* */

//   shell({ execPath : 'echo', args : null, passingThrough : 1 })
//   .then( function( op )
//   {
//     test.identical( op.exitCode, 0 );
//     test.identical( op.ended, true );
//     if( process.platform === 'win32' )
//     test.is( _.strHas( op.output, '"' + process.argv.slice( 2 ).join( '" "' ) + '"' ) );
//     else
//     test.is( _.strHas( op.output, process.argv.slice( 2 ).join( ' ') ) );
//     return null;
//   })
}

//

function startNormalizedExecPath( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.path.normalize( a.program( testApp ) ) );

  /* */

  let shell = _.process.starter
  ({
    outputCollecting : 1,
    ready : a.ready
  })

  /* */

  shell
  ({
    execPath : testAppPath,
    args : [ 'arg1', 'arg2' ],
    mode : 'fork'
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg1', 'arg2' ]` ), 1 );
    return null;
  })

  /* */

  shell
  ({
    execPath : 'node ' + testAppPath,
    args : [ 'arg1', 'arg2' ],
    mode : 'spawn'
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg1', 'arg2' ]` ), 1 );
    return null;
  })

  /* */

  shell
  ({
    execPath : 'node ' + testAppPath,
    args : [ 'arg1', 'arg2' ],
    mode : 'shell'
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg1', 'arg2' ]` ), 1 );
    return null;
  })

  /* app path in arguments */

  shell
  ({
    args : [ testAppPath, 'arg1', 'arg2' ],
    mode : 'fork'
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg1', 'arg2' ]` ), 1 );
    return null;
  })

  /* */

  shell
  ({
    execPath : 'node',
    args : [ testAppPath, 'arg1', 'arg2' ],
    mode : 'spawn'
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg1', 'arg2' ]` ), 1 );
    return null;
  })

  /* */

  shell
  ({
    execPath : 'node',
    args : [ testAppPath, 'arg1', 'arg2' ],
    mode : 'shell'
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( op.output, `[ 'arg1', 'arg2' ]` ), 1 );
    return null;
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

//

function startExecPathWithSpace( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( { routine : testApp, dirPath : 'path with space' } );

  let execPathWithSpace = 'node ' + testAppPath;

  /* - */

  a.ready.then( () =>
  {
    test.case = 'execPath contains unquoted path with space, spawn'
    return null;
  })

  _.process.start
  ({
    execPath : execPathWithSpace,
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'spawn',
    throwingExitCode : 0
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Error: Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'execPath contains unquoted path with space, shell'
    return null;
  })

  _.process.start
  ({
    execPath : execPathWithSpace,
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'shell',
    throwingExitCode : 0
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Error: Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'execPath contains unquoted path with space, fork'
    return null;
  })

  _.process.start
  ({
    execPath : a.path.nativize( testAppPath ),
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'fork',
    throwingExitCode : 0
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Error: Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space, spawn'
    return null;
  })

  _.process.start
  ({
    args : execPathWithSpace,
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'spawn',
    throwingExitCode : 0
  });

  a.ready.finally( ( err, op ) =>
  {
    _.errAttend( err );
    test.is( !!err );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( err.message, `ENOENT` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space, shell'
    return null;
  })

  _.process.start
  ({
    args : execPathWithSpace,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'shell',
    ready : a.ready,
    throwingExitCode : 0
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space, fork'
    return null;
  })

  _.process.start
  ({
    args : a.path.nativize( testAppPath ),
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'fork',
    throwingExitCode : 0
  });

  a.ready.then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space and argument, fork'
    return null;
  })

  _.process.start
  ({
    args : a.path.nativize( testAppPath ) + ' arg',
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'fork',
    throwingExitCode : 0
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Cannot find module` ) );
    return null;
  })

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.pid )
    setTimeout( () => {}, 2000 )
  }
}

//

function startNjsPassingThroughExecPathWithSpace( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program({ routine : testApp, dirPath : 'path with space' });

  let execPathWithSpace = testAppPath;

  /* - */

  a.ready.then( () =>
  {
    test.case = 'execPath contains unquoted path with space'
    return null;
  })

  _.process.startNjsPassingThrough
  ({
    execPath : execPathWithSpace,
    ready : a.ready,
    stdio : 'pipe',
    outputCollecting : 1,
    outputPiping : 1,
    throwingExitCode : 0,
    applyingExitCode : 0,
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Error: Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args: string that contains unquoted path with space'
    return null;
  })

  test.shouldThrowErrorSync( () =>
  {
    return _.process.startNjsPassingThrough
    ({
      args : execPathWithSpace,
      stdio : 'pipe',
      outputCollecting : 1,
      outputPiping : 1,
      throwingExitCode : 0,
      applyingExitCode : 0,
    });
  })

  /* - */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.pid )
    setTimeout( () => {}, 2000 )
  }
}

//

function startPassingThroughExecPathWithSpace( test ) /* qqq for Yevhen : subroutine for modes */
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program({ routine : testApp, dirPath : 'path with space' });
  let execPathWithSpace = 'node ' + _.path.nativize( testAppPath );

  /* - */

  a.ready.then( () =>
  {
    test.case = 'execPath contains unquoted path with space, spawn'
    return null;
  })

  _.process.startPassingThrough
  ({
    execPath : execPathWithSpace,
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'spawn',
    throwingExitCode : 0,
    applyingExitCode : 0,
    stdio : 'pipe'
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Error: Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'execPath contains unquoted path with space, shell'
    return null;
  })

  _.process.startPassingThrough
  ({
    execPath : execPathWithSpace,
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'shell',
    throwingExitCode : 0,
    applyingExitCode : 0,
    stdio : 'pipe'
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Error: Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'execPath contains unquoted path with space, fork'
    return null;
  })

  _.process.startPassingThrough
  ({
    execPath : a.path.nativize( testAppPath ),
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'spawn',
    throwingExitCode : 0,
    applyingExitCode : 0,
    stdio : 'pipe'
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Error: Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space, spawn'
    return null;
  })

  _.process.startPassingThrough
  ({
    args : execPathWithSpace,
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'spawn',
    throwingExitCode : 0,
    applyingExitCode : 0,
    stdio : 'pipe'
  });

  a.ready.finally( ( err, op ) =>
  {
    _.errAttend( err );
    test.is( !!err );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( err.message, `ENOENT` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space, shell'
    return null;
  })

  _.process.startPassingThrough
  ({
    args : execPathWithSpace,
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'shell',
    throwingExitCode : 0,
    applyingExitCode : 0,
    stdio : 'pipe'
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Cannot find module` ) );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space, fork'
    return null;
  })

  _.process.startPassingThrough
  ({
    args : a.path.nativize( testAppPath ),
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'fork',
    throwingExitCode : 0,
    applyingExitCode : 0,
    stdio : 'pipe'
  });

  a.ready.then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    return null;
  })

  /* - */

  a.ready.then( () =>
  {
    test.case = 'args is a string with unquoted path with space and argument, fork'
    return null;
  })

  _.process.startPassingThrough
  ({
    args : a.path.nativize( testAppPath ) + ' arg',
    ready : a.ready,
    outputCollecting : 1,
    outputPiping : 1,
    mode : 'fork',
    throwingExitCode : 0,
    applyingExitCode : 0,
    stdio : 'pipe'
  });

  a.ready.then( ( op ) =>
  {
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( a.fileProvider.fileExists( testAppPath ) );
    test.is( _.strHas( op.output, `Cannot find module` ) );
    return null;
  })

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.pid )
    setTimeout( () => {}, 2000 )
  }
}



// --
// procedures / chronology / structural
// --

function startProcedureTrivial( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );

  let start = _.process.starter
  ({
    currentPath : a.routinePath,
    outputPiping : 1,
    outputCollecting : 1,
  });

  a.ready

  /* */

  .then( () =>
  {

    var o = { execPath : 'node ' + testAppPath, mode : 'shell' }
    var con = start( o );
    var procedure = _.procedure.find( 'PID:' + o.process.pid );
    test.identical( procedure.length, 1 );
    test.identical( procedure[ 0 ].isAlive(), true );
    test.identical( o.procedure, procedure[ 0 ] );
    test.identical( procedure[ 0 ].object(), o.process );
    return con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( procedure[ 0 ].isAlive(), false );
      test.identical( o.procedure, procedure[ 0 ] );
      test.identical( procedure[ 0 ].object(), o.process );
      test.is( _.strHas( o.procedure._sourcePath, 'Execution.s' ) ); debugger;
      return null;
    })
  })

  /* */

  .then( () =>
  {

    var o = { execPath : testAppPath, mode : 'fork' }
    var con = start( o );
    var procedure = _.procedure.find( 'PID:' + o.process.pid );
    test.identical( procedure.length, 1 );
    test.identical( procedure[ 0 ].isAlive(), true );
    test.identical( o.procedure, procedure[ 0 ] );
    test.identical( procedure[ 0 ].object(), o.process );
    return con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( procedure[ 0 ].isAlive(), false );
      test.identical( o.procedure, procedure[ 0 ] );
      test.identical( procedure[ 0 ].object(), o.process );
      test.is( _.strHas( o.procedure._sourcePath, 'Execution.s' ) );
      return null;
    })
  })

  /* */

  .then( () =>
  {

    var o = { execPath : 'node ' + testAppPath, mode : 'spawn' }
    var con = start( o );
    var procedure = _.procedure.find( 'PID:' + o.process.pid );
    test.identical( procedure.length, 1 );
    test.identical( procedure[ 0 ].isAlive(), true );
    test.identical( o.procedure, procedure[ 0 ] );
    test.identical( procedure[ 0 ].object(), o.process );
    return con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( procedure[ 0 ].isAlive(), false );
      test.identical( o.procedure, procedure[ 0 ] );
      test.identical( procedure[ 0 ].object(), o.process );
      test.is( _.strHas( o.procedure._sourcePath, 'Execution.s' ) );
      return null;
    })
  })

  /* */


  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.pid )
    setTimeout( () => {}, 2000 )
  }
}

startProcedureTrivial.description =
`
  Start routine creates procedure for new child process, start it and terminates when process closes
`

//

function startProcedureExists( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( program1 ) );

  let start = _.process.starter
  ({
    currentPath : a.routinePath,
    outputPiping : 1,
    outputCollecting : 1,
  });

  _.process.watcherEnable();

  let modes = [ 'spawn', 'shell', 'fork' ];

  modes.forEach( mode =>
  {
    a.ready.tap( () => test.open( mode ) );
    a.ready.then( () => run( mode ) );
    a.ready.tap( () => test.close( mode ) );
  })

  a.ready.then( () => _.process.watcherDisable() );

  return a.ready

  /* */

  function run( mode )
  {
    let ready = _.Consequence().take( null );

    ready.then( () =>
    {
      var o = { execPath : 'node ' + testAppPath, mode }
      if( mode === 'fork' )
      o.execPath = testAppPath;
      var con = start( o );
      var procedure = _.procedure.find( 'PID:' + o.process.pid );
      test.identical( procedure.length, 1 );
      test.identical( procedure[ 0 ].isAlive(), true );
      test.identical( o.procedure, procedure[ 0 ] );
      test.identical( procedure[ 0 ].object(), o.process );
      test.identical( o.procedure, procedure[ 0 ] );
      return con.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( procedure[ 0 ].isAlive(), false );
        test.identical( o.procedure, procedure[ 0 ] );
        test.identical( procedure[ 0 ].object(), o.process );
        test.identical( o.procedure, procedure[ 0 ] );
        debugger
        test.is( _.strHas( o.procedure._sourcePath, 'Execution.s' ) );
        return null;
      })
    })

    return ready;
  }

  /* */


  function program1()
  {
    console.log( process.pid )
    setTimeout( () => {}, 2000 )
  }

}

startProcedureExists.description =
`
  Start routine does not create procedure for new child process if it was already created by process watcher
`

//

function startProcedureStack( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  // let modes = [ 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 1, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 1, mode ) ) );
  return a.ready;

  /*  */

  function run( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    /* */

    ready.then( function case1()
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode} stack:implicit`;
      let t1 = _.time.now();
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath} id:1` : `${programPath} id:1`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        mode,
        sync,
        deasync,
      }

      _.process.start( o );

      test.identical( _.strCount( o.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
      test.identical( _.strCount( o.procedure._sourcePath, 'case1' ), 1 );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( _.strCount( op.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
        test.identical( _.strCount( op.procedure._sourcePath, 'case1' ), 1 );
        return null;
      })

      return o.ready;
    })

    /* */

    ready.then( function case1()
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode} stack:true`;
      let t1 = _.time.now();
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath} id:1` : `${programPath} id:1`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        stack : true,
        mode,
        sync,
        deasync,
      }

      _.process.start( o );

      test.identical( _.strCount( o.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
      test.identical( _.strCount( o.procedure._sourcePath, 'case1' ), 1 );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( _.strCount( op.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
        test.identical( _.strCount( op.procedure._sourcePath, 'case1' ), 1 );
        return null;
      })

      return o.ready;
    })

    /* */

    ready.then( function case1()
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode} stack:0`;
      let t1 = _.time.now();
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath} id:1` : `${programPath} id:1`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        stack : 0,
        mode,
        sync,
        deasync,
      }

      _.process.start( o );

      test.identical( _.strCount( o.procedure._stack, 'case1' ), 1 );
      test.identical( _.strCount( o.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
      test.identical( _.strCount( o.procedure._sourcePath, 'case1' ), 1 );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( _.strCount( o.procedure._stack, 'case1' ), 1 );
        test.identical( _.strCount( op.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
        test.identical( _.strCount( op.procedure._sourcePath, 'case1' ), 1 );
        return null;
      })

      return o.ready;
    })

    /* */

    ready.then( function case1()
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode} stack:-1`;
      let t1 = _.time.now();
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath} id:1` : `${programPath} id:1`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        stack : -1,
        mode,
        sync,
        deasync,
      }

      _.process.start( o );

      test.identical( _.strCount( o.procedure._stack, 'case1' ), 1 );
      test.identical( _.strCount( o.procedure._sourcePath, 'start' ), 1 );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( _.strCount( o.procedure._stack, 'case1' ), 1 );
        test.identical( _.strCount( op.procedure._sourcePath, 'start' ), 1 );
        return null;
      })

      return o.ready;
    })

    /* */

    ready.then( function case1()
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode} stack:false`;
      let t1 = _.time.now();
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath} id:1` : `${programPath} id:1`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        stack : false,
        mode,
        sync,
        deasync,
      }

      _.process.start( o );

      test.identical( o.procedure._stack, '' );
      test.identical( o.procedure._sourcePath, '' );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( o.procedure._stack, '' );
        test.identical( o.procedure._sourcePath, '' );
        return null;
      })

      return o.ready;
    })

    /* */

    ready.then( function case1()
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode} stack:str`;
      let t1 = _.time.now();
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath} id:1` : `${programPath} id:1`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        stack : 'abc',
        mode,
        sync,
        deasync,
      }

      _.process.start( o );

      test.identical( o.procedure._stack, 'abc' );
      test.identical( o.procedure._sourcePath, 'abc' );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( o.procedure._stack, 'abc' );
        test.identical( o.procedure._sourcePath, 'abc' );
        return null;
      })

      return o.ready;
    })

    /* */

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    let args = _.process.args();
    let data = { time : _.time.now(), id : args.map.id };
    console.log( JSON.stringify( data ) );
  }

}

startProcedureStack.description =
`
  - option stack used to get stack
  - stack may be defined relatively
  - stack may be switched off
`

//

function startProcedureStackMultiple( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  // let modes = [ 'fork', 'spawn', 'shell' ];
  let modes = [ 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 0, mode ) ) );
  // modes.forEach( ( mode ) => a.ready.then( () => run( 0, 1, mode ) ) );
  // modes.forEach( ( mode ) => a.ready.then( () => run( 1, 0, mode ) ) );
  // modes.forEach( ( mode ) => a.ready.then( () => run( 1, 1, mode ) ) );
  return a.ready;

  /*  */

  function run( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    /* */

    ready.then( function case1()
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode} stack:implicit`;
      let t1 = _.time.now();
      let o =
      {
        execPath : mode !== `fork` ? [ `node ${programPath} id:1`, `node ${programPath} id:2` ] : [ `${programPath} id:1`, `${programPath} id:2` ],
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        mode,
        sync,
        deasync,
      }

      _.process.start( o );

      test.identical( _.strCount( o.procedure._stack, 'case1' ), 1 );
      test.identical( _.strCount( o.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
      test.identical( _.strCount( o.procedure._sourcePath, 'case1' ), 1 );

      o.ready.then( ( op ) =>
      {
        debugger;
        test.is( op === o );
        test.identical( o.exitCode, 0 );
        test.identical( o.exitSignal, null );
        test.identical( o.exitReason, 'normal' );
        test.identical( o.ended, true ); /* zzz */
        test.identical( o.state, 'terminated' );

        test.identical( _.strCount( o.procedure._stack, 'case1' ), 1 );
        test.identical( _.strCount( o.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
        test.identical( _.strCount( o.procedure._sourcePath, 'case1' ), 1 );

        o.runs.forEach( ( op2 ) =>
        {
          test.identical( _.strCount( op2.procedure._stack, 'case1' ), 1 );
          test.identical( _.strCount( op2.procedure._sourcePath, 'ProcessBasic.test.s' ), 1 );
          test.identical( _.strCount( op2.procedure._sourcePath, 'case1' ), 1 );
          test.is( o.procedure !== op2.procedure );
        });

        return null;
      })

      return o.ready;
    })

    /* */

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    let args = _.process.args();
    let data = { time : _.time.now(), id : args.map.id };
    console.log( JSON.stringify( data ) );
  }

}

//

/* qqq for Yevhen : implement for other modes */
function startOnTerminateSeveralCallbacksChronology( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let track = [];

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'parent disconnects detached child process and exits, child contiues to work'
    let o =
    {
      execPath : 'node program1.js',
      mode : 'spawn',
      stdio : 'pipe',
      outputPiping : 1,
      outputCollecting : 1,
      currentPath : a.routinePath,
      detaching : 0,
      ipc : 1,
    }
    let con = _.process.start( o );

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate.1' );
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      return null;
    })

    o.conTerminate.then( () =>
    {
      track.push( 'conTerminate.2' );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return _.time.out( 1000 + context.t2 );
    })

    o.conTerminate.then( () =>
    {
      track.push( 'conTerminate.3' );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      return null;
    })

    track.push( 'end' );
    return con;
  })

  .tap( () =>
  {
    track.push( 'ready' );
  })

  /*  */

  return _.time.out( 1000 + context.t2 + context.t2, () =>
  {
    test.identical( track, [ 'end', 'conTerminate.1', 'conTerminate.2', 'ready', 'conTerminate.3' ] );
  });

  /* - */

  function program1()
  {
    console.log( 'program1:begin' );
    setTimeout( () => { console.log( 'program1:end' ) }, 1000 );
  }

}

startOnTerminateSeveralCallbacksChronology.description =
`
- second onTerminal callbacks called after ready callback
`

//

function startChronology( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );
  let track;
  let niteration = 0;

  var modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, mode ) ) );

  return a.ready;

  /* */

  function run( sync, mode )
  {
    test.case = `sync:${sync} mode:${mode}`;

    if( sync && mode === 'fork' )
    return null;

    niteration += 1;
    let ptcounter = _.Procedure.Counter;
    let pacounter = _.Procedure.FindAlive().length;
    track = [];

    var o =
    {
      execPath : mode !== 'fork' ? 'node' : null,
      args : [ testAppPath ],
      mode,
      sync,
      ready : new _.Consequence().take( null ),
      conStart : new _.Consequence(),
      conDisconnect : new _.Consequence(),
      conTerminate : new _.Consequence(),
    }

    test.identical( _.Procedure.Counter - ptcounter, 0 );
    ptcounter = _.Procedure.Counter;
    test.identical( _.Procedure.FindAlive().length - pacounter, 0 );
    pacounter = _.Procedure.FindAlive().length;

    o.conStart.tap( ( err, op ) =>
    {
      track.push( 'conStart' );

      test.identical( err, undefined );
      test.identical( op, o );

      test.identical( o.ready.resourcesCount(), 0 );
      test.identical( o.ready.errorsCount(), 0 );
      test.identical( o.ready.competitorsCount(), 0 );
      test.identical( o.conStart.resourcesCount(), 1 );
      test.identical( o.conStart.errorsCount(), 0 );
      test.identical( o.conStart.competitorsCount(), 0 );
      test.identical( o.conDisconnect.resourcesCount(), 0 );
      test.identical( o.conDisconnect.errorsCount(), 0 );
      test.identical( o.conDisconnect.competitorsCount(), 0 );
      test.identical( o.conTerminate.resourcesCount(), 0 );
      test.identical( o.conTerminate.errorsCount(), 0 );
      test.identical( o.conTerminate.competitorsCount(), 1 );
      test.identical( o.ended, false );
      test.identical( o.state, 'started' );
      test.identical( o.error, null );
      test.identical( o.exitCode, null );
      test.identical( o.exitSignal, null );
      test.identical( o.process.exitCode, sync ? undefined : null );
      test.identical( o.process.signalCode, sync ? undefined : null );
      test.identical( _.Procedure.Counter - ptcounter, sync ? 3 : 2 );
      ptcounter = _.Procedure.Counter;
      test.identical( _.Procedure.FindAlive().length - pacounter, sync ? 1 : 2 );
      pacounter = _.Procedure.FindAlive().length;
    });

    test.identical( _.Procedure.Counter - ptcounter, 1 );
    ptcounter = _.Procedure.Counter;
    test.identical( _.Procedure.FindAlive().length - pacounter, 1 );
    pacounter = _.Procedure.FindAlive().length;

    o.conTerminate.tap( ( err, op ) =>
    {
      track.push( 'conTerminate' );

      test.identical( err, undefined );
      test.identical( op, o );

      test.identical( o.ready.resourcesCount(), 0 );
      test.identical( o.ready.errorsCount(), 0 );
      test.identical( o.ready.competitorsCount(), sync ? 0 : 1 );
      test.identical( o.conStart.resourcesCount(), 1 );
      test.identical( o.conStart.errorsCount(), 0 );
      test.identical( o.conStart.competitorsCount(), 0 );
      test.identical( o.conDisconnect.resourcesCount(), 0 );
      test.identical( o.conDisconnect.errorsCount(), 0 );
      test.identical( o.conDisconnect.competitorsCount(), 0 );
      test.identical( o.conTerminate.resourcesCount(), 1 );
      test.identical( o.conTerminate.errorsCount(), 0 );
      test.identical( o.conTerminate.competitorsCount(), 0 );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.error, null );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.process.exitCode, 0 );
      test.identical( o.process.signalCode, null );
      test.identical( _.Procedure.Counter - ptcounter, sync ? 0 : 1 );
      ptcounter = _.Procedure.Counter;
      if( sync )
      test.identical( _.Procedure.FindAlive().length - pacounter, -2 );
      else
      test.identical( _.Procedure.FindAlive().length - pacounter, niteration > 1 ? -2 : 0 );
      pacounter = _.Procedure.FindAlive().length;
      /*
      2 extra procedures dies here on non-first iteration
        2 procedures of _.time.out()
      */
    })

    let result = _.time.out( 1000 + context.t2, () =>
    {
      test.identical( track, [ 'conStart', 'conTerminate', 'ready' ] );

      test.identical( o.ready.resourcesCount(), 1 );
      test.identical( o.ready.errorsCount(), 0 );
      test.identical( o.ready.competitorsCount(), 0 );
      test.identical( o.conStart.resourcesCount(), 1 );
      test.identical( o.conStart.errorsCount(), 0 );
      test.identical( o.conStart.competitorsCount(), 0 );
      test.identical( o.conDisconnect.resourcesCount(), 0 );
      test.identical( o.conDisconnect.errorsCount(), 0 );
      test.identical( o.conDisconnect.competitorsCount(), 0 );
      test.identical( o.conTerminate.resourcesCount(), 1 );
      test.identical( o.conTerminate.errorsCount(), 0 );
      test.identical( o.conTerminate.competitorsCount(), 0 );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.error, null );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.exitSignal, null );
      test.identical( o.process.exitCode, 0 );
      test.identical( o.process.signalCode, null );
      test.identical( _.Procedure.Counter - ptcounter, 0 );
      ptcounter = _.Procedure.Counter;
      if( sync )
      test.identical( _.Procedure.FindAlive().length - pacounter, niteration > 1 ? -3 : -1 );
      else
      test.identical( _.Procedure.FindAlive().length - pacounter, -1 );
      pacounter = _.Procedure.FindAlive().length;
      /*
      2 extra procedures dies here on non-first iteration
        2 procedures of _.time.out()
      */
    });

    test.identical( _.Procedure.Counter - ptcounter, 3 );
    ptcounter = _.Procedure.Counter;
    test.identical( _.Procedure.FindAlive().length - pacounter, 3 );
    pacounter = _.Procedure.FindAlive().length;

    let returned = _.process.start( o );

    if( sync )
    test.is( returned === o );
    else
    test.is( returned === o.ready );
    test.is( o.conStart !== o.ready );
    test.is( o.conDisconnect !== o.ready );
    test.is( o.conTerminate !== o.ready );

    test.identical( o.ready.resourcesCount(), sync ? 1 : 0 );
    test.identical( o.ready.errorsCount(), 0 );
    test.identical( o.ready.competitorsCount(), 0 );
    test.identical( o.conStart.resourcesCount(), 1 );
    test.identical( o.conStart.errorsCount(), 0 );
    test.identical( o.conStart.competitorsCount(), 0 );
    test.identical( o.conDisconnect.resourcesCount(), 0 );
    test.identical( o.conDisconnect.errorsCount(), 0 );
    test.identical( o.conDisconnect.competitorsCount(), 0 );
    test.identical( o.conTerminate.resourcesCount(), sync ? 1 : 0 );
    test.identical( o.conTerminate.errorsCount(), 0 );
    test.identical( o.conTerminate.competitorsCount(), sync ? 0 : 1 );
    test.identical( o.ended, sync ? true : false );
    test.identical( o.state, sync ? 'terminated' : 'started' );
    test.identical( o.error, null );
    test.identical( o.exitCode, sync ? 0 : null );
    test.identical( o.exitSignal, null );
    test.identical( o.process.exitCode, sync ? 0 : null );
    test.identical( o.process.signalCode, null );
    test.identical( _.Procedure.Counter - ptcounter, 0 );
    ptcounter = _.Procedure.Counter;
    test.identical( _.Procedure.FindAlive().length - pacounter, sync ? -1 : -2 );
    pacounter = _.Procedure.FindAlive().length;

    o.ready.tap( ( err, op ) =>
    {
      track.push( 'ready' );

      test.identical( err, undefined );
      test.identical( op, o );

      test.identical( o.ready.resourcesCount(), 1 );
      test.identical( o.ready.errorsCount(), 0 );
      test.identical( o.ready.competitorsCount(), 0 );
      test.identical( o.conStart.resourcesCount(), 1 );
      test.identical( o.conStart.errorsCount(), 0 );
      test.identical( o.conStart.competitorsCount(), 0 );
      test.identical( o.conDisconnect.resourcesCount(), 0 );
      test.identical( o.conDisconnect.errorsCount(), 0 );
      test.identical( o.conDisconnect.competitorsCount(), 0 );
      test.identical( o.conTerminate.resourcesCount(), 1 );
      test.identical( o.conTerminate.errorsCount(), 0 );
      test.identical( o.conTerminate.competitorsCount(), 0 );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.error, null );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.exitSignal, null );
      test.identical( o.process.exitCode, 0 );
      test.identical( o.process.signalCode, null );
      test.identical( _.Procedure.Counter - ptcounter, sync ? 1 : 0 );
      ptcounter = _.Procedure.Counter;
      test.identical( _.Procedure.FindAlive().length - pacounter, sync ? 1 : -1 );
      pacounter = _.Procedure.FindAlive().length;
      return null;
    })

    return result;
  }

  /* - */

  function testApp()
  {
    setTimeout( () => {}, 1000 );
  }

}

startChronology.description =
`
  - conTerminate goes before ready
  - conStart goes before conTerminate
  - procedures generated
  - no extra procedures generated
`

// --
// delay
// --

function startReadyDelay( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  // let modes = [ 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => single( 0, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => single( 0, 1, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => single( 1, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => single( 1, 1, mode ) ) );
  return a.ready;

  /*  */

  function single( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    ready.then( () =>
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode}`;
      let t1 = _.time.now();
      let ready = new _.Consequence().take( null ).timeOut( context.t2 );
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath} id:1` : `${programPath} id:1`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        mode,
        sync,
        deasync,
        ready,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        let parsed = JSON.parse( op.output );
        let diff = parsed.time - t1;
        console.log( diff );
        test.ge( diff, context.t2 );
        return null;
      })

      return returned;
    })

    return ready;
  }

  /*  */

  /* xxx : make multiple work */
  function multiple( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    ready.then( () =>
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode}`;
      let t1 = _.time.now();
      let ready = new _.Consequence().take( null ).timeOut( context.t2 );
      let o =
      {
        execPath : mode !== `fork` ? [ `node ${programPath} id:1`, `node ${programPath} id:2` ] : [ `${programPath} id:1`, `${programPath} id:2` ],
        currentPath : a.abs( '.' ),
        outputPiping : 1,
        outputCollecting : 1,
        // returningOptionsArray : 0,
        mode,
        sync,
        deasync,
        ready,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        debugger;
        test.is( op === o );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        let parsed = JSON.parse( op.output );
        let diff = parsed.time - t1;
        console.log( diff );
        test.ge( diff, context.t2 );
        return null;
      })

      return returned;
    })

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    let args = _.process.args();
    let data = { time : _.time.now(), id : args.map.id };
    console.log( JSON.stringify( data ) );
  }

}

startReadyDelay.timeOut = 300000;

//

function startReadyDelayMultiple( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  // let modes = [ 'fork', 'spawn', 'shell' ];
  let modes = [ 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => multiple( 0, 0, mode ) ) );
  // modes.forEach( ( mode ) => a.ready.then( () => multiple( 0, 1, mode ) ) );
  // modes.forEach( ( mode ) => a.ready.then( () => multiple( 1, 0, mode ) ) );
  // modes.forEach( ( mode ) => a.ready.then( () => multiple( 1, 1, mode ) ) );
  return a.ready;

  /*  */

  /* xxx : make multiple work */
  /* xxx : review */
  function multiple( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    ready.then( () =>
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode}`;
      let t1 = _.time.now();
      let ready = new _.Consequence().take( null ).timeOut( context.t2 );
      let o =
      {
        execPath : mode !== `fork` ? [ `node ${programPath} id:1`, `node ${programPath} id:2` ] : [ `${programPath} id:1`, `${programPath} id:2` ],
        currentPath : a.abs( '.' ),
        outputPiping : 1,
        outputCollecting : 1,
        // returningOptionsArray : 0,
        mode,
        sync,
        deasync,
        ready,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        debugger;
        test.is( op === o );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        op.runs.forEach( ( op2 ) =>
        {
          console.log( `op.output : ${op2.output}` );
          let parsed = JSON.parse( op2.output );
          let diff = parsed.time - t1;
          console.log( diff );
          test.ge( diff, context.t2 );
        });
        return null;
      })

      return returned;
    })

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    let args = _.process.args();
    let data = { time : _.time.now(), id : args.map.id };
    console.log( JSON.stringify( data ) );
  }

}

startReadyDelayMultiple.timeOut = 300000;

//

function startOptionWhenDelay( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  // let modes = [ 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 1, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 1, mode ) ) );
  return a.ready;

  /*  */

  function run( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    ready.then( () =>
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode}`;
      let t1 = _.time.now();
      let when = { delay : context.t2 };
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        mode,
        outputPiping : 1,
        outputCollecting : 1,
        when : when,
        sync,
        deasync,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        let parsed = JSON.parse( op.output );
        let diff = parsed.time - t1;
        console.log( diff );
        test.ge( diff, when.delay );
        return null;
      })

      return returned;
    })

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    let data = { time : _.time.now() };
    console.log( JSON.stringify( data ) );
  }

}

startOptionWhenDelay.timeOut = 300000;

//

function startOptionWhenTime( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 1, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 1, mode ) ) );
  return a.ready;

  /* */

  function run( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    ready.then( () =>
    {
      test.case = `sync:${sync} deasync:${deasync} mode:${mode}`;

      let t1 = _.time.now();
      let delay = 5000;
      let when = { time : _.time.now() + delay };
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        mode,
        outputPiping : 1,
        outputCollecting : 1,
        when,
        sync,
        deasync,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        let parsed = JSON.parse( op.output );
        let diff = parsed.time - t1;
        test.ge( diff, delay );
        return null;
      })

      return returned;
    })

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );

    let data = { time : _.time.now() };
    console.log( JSON.stringify( data ) );
  }
}

startOptionWhenTime.timeOut = 300000;

//

function startOptionTimeOut( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath1 = a.program({ routine : program1 });
  let programPath2 = a.program({ routine : program2 });
  let programPath3 = a.program({ routine : program3 });
  let programPath4 = a.program({ routine : program4 });
  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( mode ) ) );
  return a.ready;

  function run( mode )
  {
    let ready = _.Consequence().take( null )

    ready.then( () =>
    {
      test.case = `mode:${mode}, child process runs for some time`;

      let o =
      {
        execPath : mode === 'fork' ? 'program1.js' : `node program1.js`,
        mode,
        currentPath : a.routinePath,
        timeOut : context.t1,
      }

      _.process.start( o );

      return test.shouldThrowErrorAsync( o.conTerminate )
      .then( () =>
      {
        test.notIdentical( o.exitCode, 0 );
        test.identical( o.ended, true );

        if( process.platform === 'win32' )
        test.identical( o.exitSignal, null );
        else
        test.identical( o.exitSignal, 'SIGTERM' );

        return null;
      })
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode}, child process ignores SIGTERM`;

      let o =
      {
        execPath : mode === 'fork' ? 'program2.js' : `node program2.js`,
        mode,
        currentPath : a.routinePath,
        timeOut : context.t1,
      }

      _.process.start( o );

      return test.shouldThrowErrorAsync( o.conTerminate )
      .then( () =>
      {
        test.notIdentical( o.exitCode, 0 );
        test.identical( o.ended, true );

        if( process.platform === 'win32' )
        test.identical( o.exitSignal, null );
        else
        test.identical( o.exitSignal, 'SIGKILL' );

        return null;
      })
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode}, process has single child that runs normally, process waits until child will exit`;

      let o =
      {
        execPath : mode === 'fork' ? 'program3.js' : `node program3.js`,
        args : 'program1.js',
        mode,
        currentPath : a.routinePath,
        timeOut : context.t1,
        outputPiping : 1,
        outputCollecting : 1
      }

      _.process.start( o );

      return test.shouldThrowErrorAsync( o.conTerminate )
      .then( ( got ) =>
      {
        test.notIdentical( o.exitCode, 0 );
        test.identical( o.ended, true );

        if( process.platform === 'win32' )
        test.identical( o.exitSignal, null );
        else
        test.identical( o.exitSignal, 'SIGTERM' );

        test.is( _.strHas( o.output, 'Process was killed by exit signal SIGTERM' ) );

        return null;
      })
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode}, parent and child ignore SIGTERM`;

      let o =
      {
        execPath : mode === 'fork' ? 'program4.js' : `node program4.js`,
        args : 'program2.js',
        mode,
        currentPath : a.routinePath,
        timeOut : context.t1,
        outputPiping : 1,
        outputCollecting : 1
      }

      _.process.start( o );

      return test.shouldThrowErrorAsync( o.conTerminate )
      .then( ( got ) =>
      {
        test.notIdentical( o.exitCode, 0 );
        test.identical( o.ended, true );

        if( process.platform === 'win32' )
        test.identical( o.exitSignal, null );
        else
        test.identical( o.exitSignal, 'SIGKILL' );

        return null;
      })
    })

    return ready;
  }

  /* */

  function program1()
  {
    console.log( 'program1::start' )
    setTimeout( () =>
    {
      console.log( 'program1::end' )
    }, context.t2 )
  }

  /* */

  function program2()
  {
    console.log( 'program2::start', process.pid )
    setTimeout( () =>
    {
      console.log( 'program2::end' )
    }, context.t2 * 3 )

    process.on( 'SIGTERM', () =>
    {
      console.log( 'program2: SIGTERM is ignored')
    })
  }

  /* */

  function program3()
  {
    let _ = require( toolsPath );
    _.include( 'wFiles' );
    _.include( 'wProcess' );

    process.removeAllListeners( 'SIGTERM' ); /* clear listeners defined in wProcess */

    let o =
    {
      execPath : 'node',
      args : process.argv.slice( 2 ),
      mode : 'spawn',
      currentPath : __dirname,
      stdio : 'pipe',
      outputPiping : 1,
    }
    _.process.start( o );

    /* ignores SIGTERM until child process will be terminated, then emits SIGTERM by itself */
    process.on( 'SIGTERM', () =>
    {
      o.conTerminate.catch( ( err ) =>
      {
        _.errLogOnce( err );
        process.removeAllListeners( 'SIGTERM' );
        process.kill( process.pid, 'SIGTERM' );
        return null;
      })
    })
  }

  /* */

  function program4()
  {
    let _ = require( toolsPath );
    _.include( 'wFiles' );
    _.include( 'wProcess' );

    process.removeAllListeners( 'SIGTERM' ); /* clear listeners defined in wProcess */

    let o =
    {
      execPath : 'node',
      args : process.argv.slice( 2 ),
      mode : 'spawn',
      currentPath : __dirname,
      stdio : 'pipe',
      outputPiping : 1,
    }
    _.process.start( o );

    /* ignores SIGTERM until child process will be terminated */
    process.on( 'SIGTERM', () =>
    {
      o.conTerminate.catch( ( err ) =>
      {
        _.errLogOnce( err );
        return null;
      })
    })
  }

  /* */

}

startOptionTimeOut.timeOut = 300000;

//

function startAfterDeath( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let stack = [];
  let testAppParentPath = a.program( testAppParent );
  let testAppChildPath = a.program( testAppChild );

  /* */

  let testFilePath = a.abs( a.routinePath, 'testFile' );

  a.ready

  .then( () =>
  {
    let o =
    {
      execPath : 'node testAppParent.js',
      mode : 'spawn',
      outputCollecting : 1,
      outputPiping : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    debugger;
    let con = _.process.start( o );
    let childPid;
    debugger;

    o.process.on( 'message', ( e ) =>
    {
      childPid = _.numberFrom( e );
    })

    o.conTerminate.then( () =>
    {
      stack.push( 'conTerminate' );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.case = 'secondary process is alive'
      test.is( _.process.isAlive( childPid ) );
      test.case = 'child of secondary process does not exit yet'
      test.is( !a.fileProvider.fileExists( testFilePath ) );
      return _.time.out( 10000 );
    })

    o.conTerminate.then( () =>
    {
      stack.push( 'conTerminate' );
      test.identical( stack, [ 'conTerminate', 'conTerminate' ] );
      test.case = 'secondary process is dead'
      test.is( !_.process.isAlive( childPid ) );

      test.case = 'child of secondary process is executed'
      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid2 = a.fileProvider.fileRead( testFilePath );
      childPid2 = _.numberFrom( childPid2 );

      test.case = 'secondary process and child are not same'
      test.is( !_.process.isAlive( childPid2 ) );
      test.notIdentical( childPid, childPid2 );
      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let o =
    {
      execPath : 'node testAppChild.js',
      outputCollecting : 1,
      mode : 'spawn',
    }

    _.process.startAfterDeath( o );

    o.conStart.thenGive( () =>
    {
      process.send( o.process.pid );
    })

    _.time.out( 5000, () =>
    {
      console.log( 'parent termination begin' );
      _.procedure.terminationBegin();
      return null;
    })
  }

  /* */

  function testAppChild()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wFiles' );

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
    })
  }

}

//

// function startAfterDeathOutput( test )
// {
//   let context = this;
//   var routinePath = _.path.join( context.suiteTempPath, test.name );

//   function testAppParent()
//   {
//     _.include( 'wProcess' );
//     _.include( 'wFiles' );

//     let o =
//     {
//       execPath : 'node testAppChild.js',
//       outputCollecting : 1,
//       stdio : 'inherit',
//       mode : 'spawn',
//       when : 'afterdeath'
//     }

//     _.process.start( o );

//     _.time.out( 4000, () =>
//     {
//       console.log( 'Parent process exit' )
//       process.disconnect();
//       return null;
//     })
//   }

//   function testAppChild()
//   {
//     _.include( 'wProcess' );
//     _.include( 'wFiles' );

//     console.log( 'Child process start' )

//     _.time.out( 5000, () =>
//     {
//       console.log( 'Child process end' )
//     })
//   }

//   /* */

//   var testAppParentPath = _.fileProvider.path.nativize( _.path.join( routinePath, 'testAppParent.js' ) );
//   var testAppChildPath = _.fileProvider.path.nativize( _.path.join( routinePath, 'testAppChild.js' ) );
//   var testAppParentCode = context.toolsPathInclude + testAppParent.toString() + '\ntestAppParent();';
//   var testAppChildCode = context.toolsPathInclude + testAppChild.toString() + '\ntestAppChild();';
//   _.fileProvider.fileWrite( testAppParentPath, testAppParentCode );
//   _.fileProvider.fileWrite( testAppChildPath, testAppChildCode );
//   testAppParentPath = _.strQuote( testAppParentPath );
//   var ready = new _.Consequence().take( null );

//   ready

//   .then( () =>
//   {
//     let o =
//     {
//       execPath : 'node testAppParent.js',
//       mode : 'spawn',
//       outputCollecting : 1,
//       currentPath : routinePath,
//       ipc : 1,
//     }
//     let con = _.process.start( o );

//     con.then( ( op ) =>
//     {
//       test.identical( op.exitCode, 0 );
//       test.identical( op.ended, true );
//       test.is( _.strHas( op.output, 'Parent process exit' ) )
//       test.is( _.strHas( op.output, 'Secondary: starting child process...' ) )
//       test.is( _.strHas( op.output, 'Child process start' ) )
//       test.is( _.strHas( op.output, 'Child process end' ) )

//       return null;
//     })

//     return con;
//   })

//   /*  */

//   return ready;
// }

// --
// detaching
// --

function startDetachingModeSpawnResourceReady( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppChildPath = a.program( testAppChild );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'consequence receive resources after child spawn';

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'spawn',
      detaching : 1,
      currentPath : a.routinePath,
      throwingExitCode : 0
    }
    let result = _.process.start( o );

    test.is( result !== o.conStart );
    test.is( result !== o.conTerminate );

    o.conStart.then( ( op ) =>
    {
      track.push( 'conStart' );
      test.is( _.mapIs( op ) );
      test.identical( op, o );
      test.is( _.process.isAlive( o.process.pid ) );
      o.process.kill();
      return null;
    })

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate' );
      test.notIdentical( op.exitCode, 0 );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( track, [ 'conStart', 'conTerminate' ] );
      return null;
    })

    return o.conTerminate;
  })

  return a.ready;

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

//

function startDetachingModeForkResourceReady( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppChildPath = a.program( testAppChild );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'consequence receives resources after child spawn';

    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      detaching : 1,
      currentPath : a.routinePath,
      throwingExitCode : 0
    }
    let result = _.process.start( o );

    test.is( result !== o.conStart );
    test.is( result !== o.conTerminate );

    o.conStart.thenGive( ( op ) =>
    {
      track.push( 'conStart' );
      test.is( _.mapIs( op ) );
      test.identical( op, o );
      test.is( _.process.isAlive( o.process.pid ) );
      o.process.kill();
    })

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate' );
      test.notIdentical( op.exitCode, 0 );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( track, [ 'conStart', 'conTerminate' ] )
      return null;
    })

    return o.conTerminate;
  })

  return a.ready;

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

//

function startDetachingModeShellResourceReady( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppChildPath = a.program( testAppChild );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'consequence receives resources after child spawn';

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'shell',
      detaching : 1,
      currentPath : a.routinePath,
      throwingExitCode : 0
    }
    let result = _.process.start( o );

    test.is( result !== o.conStart );
    test.is( result !== o.conTerminate );

    o.conStart.thenGive( ( op ) =>
    {
      track.push( 'conStart' );
      test.is( _.mapIs( op ) );
      test.identical( op, o );
      test.is( _.process.isAlive( o.process.pid ) );
      o.process.kill();
    })

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate' );
      test.notIdentical( op.exitCode, 0 );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( track, [ 'conStart', 'conTerminate' ] );
      return null;
    })

    return o.conTerminate;
  })

  return a.ready;

  function testAppChild()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

//

function startDetachingModeSpawnNoTerminationBegin( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppParentPath = a.program( testAppParent );
  let testAppChildPath = a.program( testAppChild );

  let testFilePath = a.abs( a.routinePath, 'testFile' );

  a.ready

  .then( () =>
  {
    test.case = 'stdio:ignore ipc:false, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : ignore ipc : false outputPiping : 0 outputCollecting : 0',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.identical( data.childPid, childPid )

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'stdio:ignore ipc:true, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : ignore ipc : true outputPiping : 0 outputCollecting : 0',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.identical( data.childPid, childPid )

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'stdio:pipe, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : pipe',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.identical( data.childPid, childPid )

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'stdio:pipe ipc:true, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : pipe ipc : true',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.identical( data.childPid, childPid )

      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let args = _.process.args();

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'spawn',
      ipc : 0,
      detaching : true,
    }

    _.mapExtend( o, args.map );

    _.process.start( o );

    process.send({ childPid : o.process.pid });
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }


}

//

function startDetachingModeForkNoTerminationBegin( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppParentPath = a.program( testAppParent );
  let testAppChildPath = a.program( testAppChild );

  let testFilePath = a.abs( a.routinePath, 'testFile' );

  a.ready

  /*  */

  .then( () =>
  {
    test.case = 'stdio:ignore, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : ignore outputPiping : 0 outputCollecting : 0',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.identical( data.childPid, childPid )

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'stdio:pipe, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : pipe',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.identical( data.childPid, childPid )

      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let args = _.process.args();

    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      detaching : true,
    }

    _.mapExtend( o, args.map );

    _.process.start( o );

    process.send({ childPid : o.process.pid });
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }

}

//

function startDetachingModeShellNoTerminationBegin( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppParentPath = a.program( testAppParent );
  let testAppChildPath = a.program( testAppChild );

  let testFilePath = a.abs( a.routinePath, 'testFile' );

  a.ready

  .then( () =>
  {
    test.case = 'stdio:ignore, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : pipe',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.is( !_.process.isAlive( childPid ) );

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'stdio:pipe, parent should wait for child to exit';

    let o =
    {
      execPath : 'node testAppParent.js stdio : pipe',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    let con = _.process.start( o );

    let data;

    o.process.on( 'message', ( e ) =>
    {
      data = e;
      data.childPid = _.numberFrom( data.childPid );
    })

    con.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.will = 'parent and child are dead';
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( data.childPid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid );
      test.is( !_.process.isAlive( childPid ) );

      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let args = _.process.args();

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'shell',
      ipc : 0,
      detaching : true,
    }

    _.mapExtend( o, args.map );

    _.process.start( o );

    process.send({ childPid : o.process.pid });
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

//

/* qqq for Yevhen : implement for other modes */
function startDetachedOutputStdioIgnore( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppParentPath = a.program( testAppParent );
  let testAppChildPath = a.program( testAppChild );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'mode : spawn, stdio : ignore, no output from detached child';

    let o =
    {
      execPath : 'node testAppParent.js mode : spawn stdio : ignore',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
    }
    let con = _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 )
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( !_.strHas( o.output, 'Child process start' ) )
      test.is( !_.strHas( o.output, 'Child process end' ) )
      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : fork, stdio : ignore, no output from detached child';

    let o =
    {
      execPath : 'node testAppParent.js mode : fork stdio : ignore',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
    }
    let con = _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 )
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( !_.strHas( o.output, 'Child process start' ) )
      test.is( !_.strHas( o.output, 'Child process end' ) )
      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : shell, stdio : ignore, no output from detached child';

    let o =
    {
      execPath : 'node testAppParent.js mode : shell stdio : ignore',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
    }
    let con = _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 )
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( !_.strHas( o.output, 'Child process start' ) )
      test.is( !_.strHas( o.output, 'Child process end' ) )
      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */


  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let args = _.process.args();

    let o =
    {
      execPath : 'testAppChild.js',
      detaching : true,
    }

    _.mapExtend( o, args.map );

    if( o.mode !== 'fork' )
    o.execPath = 'node ' + o.execPath;

    _.process.start( o );
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      console.log( 'Child process end' )
      return null;
    })
  }

}

//

/* qqq for Yevhen : implement for other modes */
function startDetachedOutputStdioPipe( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppParentPath = a.program( testAppParent );
  let testAppChildPath = a.program( testAppChild );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'mode : spawn, stdio : pipe';

    let o =
    {
      execPath : 'node testAppParent.js mode : spawn stdio : pipe',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
    }
    let con = _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 )
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( _.strHas( o.output, 'Child process start' ) )
      test.is( _.strHas( o.output, 'Child process end' ) )
      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : fork, stdio : pipe';

    let o =
    {
      execPath : 'node testAppParent.js mode : fork stdio : pipe',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
    }
    let con = _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 )
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.is( _.strHas( o.output, 'Child process start' ) )
      test.is( _.strHas( o.output, 'Child process end' ) )
      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : shell, stdio : pipe';

    let o =
    {
      execPath : 'node testAppParent.js mode : shell stdio : pipe',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
    }
    let con = _.process.start( o );

    con.then( () =>
    {
      test.identical( o.exitCode, 0 )
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      // zzz for Vova: output piping doesn't work as expected in mode "shell" on windows
      // investigate if its fixed in never verions of node or implement alternative solution

      if( process.platform === 'win32' )
      return null;

      test.is( _.strHas( o.output, 'Child process start' ) )
      test.is( _.strHas( o.output, 'Child process end' ) )
      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let args = _.process.args();

    let o =
    {
      execPath : 'testAppChild.js',
      detaching : true,
    }

    _.mapExtend( o, args.map );

    if( o.mode !== 'fork' )
    o.execPath = 'node ' + o.execPath;

    _.process.start( o );
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      console.log( 'Child process end' )
      return null;
    })
  }


}

//

/* qqq for Yevhen : implement for other modes */
function startDetachedOutputStdioInherit( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppChildPath = a.program( testAppChild );

  /* */

  test.is( true );

  if( !Config.debug )
  return a.ready;

  a.ready

  .then( () =>
  {
    test.case = 'mode : spawn, stdio : inherit';
    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'spawn',
      stdio : 'inherit',
      detaching : 1,
      currentPath : a.routinePath,
    }
    return test.shouldThrowErrorSync( () => _.process.start( o ) );
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : fork, stdio : inherit';
    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      stdio : 'inherit',
      detaching : 1,
      currentPath : a.routinePath,
    }
    return test.shouldThrowErrorSync( () => _.process.start( o ) );
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : shell, stdio : inherit';
    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'shell',
      stdio : 'inherit',
      detaching : 1,
      currentPath : a.routinePath,
    }
    return test.shouldThrowErrorSync( () => _.process.start( o ) );
  })

  /*  */

  return a.ready;

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

//

/* qqq for Yevhen : implement for other modes */
function startDetachingModeSpawnIpc( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppChildPath = a.program( testAppChild );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'mode : spawn, stdio : ignore';

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'spawn',
      outputPiping : 0,
      outputCollecting : 0,
      stdio : 'ignore',
      currentPath : a.routinePath,
      detaching : 1,
      ipc : 1,
    }
    _.process.start( o );

    let message;

    o.process.on( 'message', ( e ) =>
    {
      message = e;
    })

    o.conStart.thenGive( () =>
    {
      track.push( 'conStart' );
      o.process.send( 'child' );
    })

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate' );
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( message, 'child' );
      test.identical( track, [ 'conStart', 'conTerminate' ] );
      track = [];
      return null;
    })

    return o.conTerminate;
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : spawn, stdio : pipe';

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'spawn',
      outputCollecting : 1,
      stdio : 'pipe',
      currentPath : a.routinePath,
      detaching : 1,
      ipc : 1,
    }
    _.process.start( o );

    let message;

    o.process.on( 'message', ( e ) =>
    {
      message = e;
    })

    o.conStart.thenGive( () =>
    {
      track.push( 'conStart' );
      o.process.send( 'child' );
    })

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate' );
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( message, 'child' );
      test.identical( track, [ 'conStart', 'conTerminate' ] );
      track = [];
      return null;
    })

    return o.conTerminate;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    process.on( 'message', ( data ) =>
    {
      process.send( data );
      process.exit();
    })

  }
}

//

/* qqq for Yevhen : implement for other modes */
function startDetachingModeForkIpc( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppChildPath = a.program( testAppChild );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'mode : fork, stdio : ignore';

    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      outputPiping : 0,
      outputCollecting : 0,
      stdio : 'ignore',
      currentPath : a.routinePath,
      detaching : 1,
      ipc : 1,
    }
    _.process.start( o );

    let message;

    o.process.on( 'message', ( e ) =>
    {
      message = e;
    })

    o.conStart.thenGive( () =>
    {
      track.push( 'conStart' );
      o.process.send( 'child' );
    })

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate' );
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( message, 'child' );
      test.identical( track, [ 'conStart', 'conTerminate' ] );
      track = [];
      return null;
    })

    return o.conTerminate;
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : fork, stdio : pipe';

    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      outputCollecting : 1,
      stdio : 'pipe',
      currentPath : a.routinePath,
      detaching : 1,
      ipc : 1,
    }
    _.process.start( o );

    let message;

    o.process.on( 'message', ( e ) =>
    {
      message = e;
    })

    o.conStart.thenGive( () =>
    {
      track.push( 'conStart' );
      o.process.send( 'child' );
    })

    o.conTerminate.then( ( op ) =>
    {
      track.push( 'conTerminate' );
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( message, 'child' );
      test.identical( track, [ 'conStart', 'conTerminate' ] );
      track = [];
      return null;
    })

    return o.conTerminate;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    process.on( 'message', ( data ) =>
    {
      process.send( data );
      process.exit();
    })

  }
}

//

/* qqq for Yevhen : implement for other modes */
function startDetachingModeShellIpc( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppChildPath = a.program( testAppChild );

  /* */

  test.is( true );

  if( !Config.debug )
  return a.ready;

  a.ready

  .then( () =>
  {
    test.case = 'mode : shell, stdio : ignore';

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'shell',
      outputCollecting : 1,
      stdio : 'ignore',
      currentPath : a.routinePath,
      detaching : 1,
      ipc : 1,
    }
    return test.shouldThrowErrorSync( () => _.process.start( o ) );
  })

  /*  */

  .then( () =>
  {
    test.case = 'mode : shell, stdio : pipe';

    let o =
    {
      execPath : 'node testAppChild.js',
      mode : 'shell',
      outputCollecting : 1,
      stdio : 'pipe',
      currentPath : a.routinePath,
      detaching : 1,
      ipc : 1,
    }
    return test.shouldThrowErrorSync( () => _.process.start( o ) );
  })

  /*  */

  return a.ready;

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    process.on( 'message', ( data ) =>
    {
      process.send( data );
      process.exit();
    })

  }
}

//

/* qqq for Yevhen : implement for other modes */
function startDetachingTrivial( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppParentPath = a.program( testAppParent );
  let testAppChildPath = a.program( testAppChild );
  let testFilePath = a.abs( a.routinePath, 'testFile' );

  /* */

  test.case = 'trivial use case';

  let o =
  {
    execPath : 'testAppParent.js',
    outputCollecting : 1,
    mode : 'fork',
    stdio : 'pipe',
    detaching : 0,
    throwingExitCode : 0,
    currentPath : a.routinePath,
  }

  _.process.start( o );

  var childPid;
  o.process.on( 'message', ( e ) =>
  {
    childPid = _.numberFrom( e );
  })

  o.conTerminate.then( ( op ) =>
  {
    track.push( 'conTerminate' );
    test.is( _.process.isAlive( childPid ) );
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.is( _.strHas( op.output, 'Child process start' ) );
    test.is( _.strHas( op.output, 'from parent: data' ) );
    test.is( !_.strHas( op.output, 'Child process end' ) );
    test.identical( o.exitCode, op.exitCode );
    test.identical( o.output, op.output );
    return _.time.out( 10000 );
  })

  o.conTerminate.then( () =>
  {
    track.push( 'conTerminate' );
    test.is( !_.process.isAlive( childPid ) );

    let childPidFromFile = a.fileProvider.fileRead( testFilePath );
    childPidFromFile = _.numberFrom( childPidFromFile )
    test.is( !_.process.isAlive( childPidFromFile ) );
    test.identical( childPid, childPidFromFile )
    test.identical( track, [ 'conTerminate', 'conTerminate' ] );
    return null;
  })

  return o.conTerminate;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    let o =
    {
      execPath : 'testAppChild.js',
      outputCollecting : 1,
      stdio : 'pipe',
      detaching : 1,
      applyingExitCode : 0,
      throwingExitCode : 0,
      outputPiping : 1,
    }
    _.process.startNjs( o );

    o.conStart.thenGive( () =>
    {
      process.send( o.process.pid )
      o.process.send( 'data' );
      o.process.on( 'message', () =>
      {
        o.disconnect();
      })
    })
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    process.on( 'message', ( data ) =>
    {
      console.log( 'from parent:', data );
      process.send( 'ready to disconnect' )
    })

    _.time.out( 5000, () =>
    {
      console.log( 'Child process end' );
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      return null;
    })

  }
}

//

function startEventClose( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program({ routine : program1 });
  let data = [];

  let modes = [ 'spawn', 'fork', 'shell' ];
  let ipc = [ false, true ]
  let disconnecting = [ false, true ];

  modes.forEach( mode =>
  {
    ipc.forEach( ipc =>
    {
      disconnecting.forEach( disconnecting =>
      {
        a.ready.then( () => run( mode,ipc,disconnecting ) );
      })
    })
  })

  a.ready.then( () =>
  {
    var dim = [ data.length / 4, 4 ];
    var style = 'doubleBorder';
    var topHead = [ 'mode', 'ipc', 'disconnecting', 'event close' ];
    var got = _.strTable({ data, dim, style, topHead, colWidth : 18 });

    var exp =
`
╔════════════════════════════════════════════════════════════════════════╗
║       mode               ipc          disconnecting      event close   ║
╟────────────────────────────────────────────────────────────────────────╢
║       spawn             false             false             true       ║
║       spawn             false             true              true       ║
║       spawn             true              false             true       ║
║       spawn             true              true              false      ║
║       fork              true              false             true       ║
║       fork              true              true              false      ║
║       shell             false             false             true       ║
║       shell             false             true              true       ║
╚════════════════════════════════════════════════════════════════════════╝
`
    test.equivalent( got.result, exp );
    console.log( got.result )
    return null;
  })

  return a.ready;

  /* - */

  function run( mode, ipc, disconnecting )
  {
    let ready = new _.Consequence().take( null );

    if( ipc && mode === 'shell' )
    return ready;

    if( !ipc && mode === 'fork' )
    return ready;

    let result = [ mode, ipc, disconnecting, false ];

    ready.then( () =>
    {
      let o =
      {
        execPath : mode === 'fork' ? 'program1.js' : 'node program1.js',
        currentPath : a.routinePath,
        stdio : 'ignore',
        detaching : 0,
        mode,
        ipc,
      }

      test.case = _.toJs({ mode, ipc, disconnecting });

      _.process.start( o );

      o.conStart.thenGive( () =>
      {
        if( disconnecting )
        o.disconnect()
      })
      o.process.on( 'close', () =>
      {
        result[ 3 ] = true;
      })

      return _.time.out( context.t1 * 3, () =>
      {
        test.is( !_.process.isAlive( o.process.pid ) );

        if( mode === 'shell' )
        test.identical( result[ 3 ], true )

        if( mode === 'spawn' )
        test.identical( result[ 3 ], ipc && disconnecting ? false : true )

        if( mode === 'fork' )
        test.identical( result[ 3 ], !disconnecting )

        data.push.apply( data, result );
        return null;
      })
    })

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath )
    console.log( 'program1::begin' );
    setTimeout( () =>
    {
      console.log( 'program1::end' );
    }, context.t1 * 2 );
  }
}

startEventClose.timeOut = 300000;
startEventClose.description =
`
Check if close event is called.
`

//

function startEventExit( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program({ routine : program1 });
  let data = [];
  let modes = [ 'spawn', 'fork', 'shell' ];
  let stdio = [ 'inherit', 'pipe', 'ignore' ];
  let ipc = [ false, true ]
  let detaching = [ false, true ]
  let disconnecting = [ false, true ];

  modes.forEach( mode =>
  {
    stdio.forEach( stdio =>
    {
      ipc.forEach( ipc =>
      {
        detaching.forEach( detaching =>
        {
          disconnecting.forEach( disconnecting =>
          {
            a.ready.then(() => run( mode, stdio, ipc, detaching, disconnecting ) );
          })
        })
      })
    })
  })

  a.ready.then( () =>
  {
    var dim = [ data.length / 6, 6 ];
    var style = 'doubleBorder';
    var topHead = [ 'mode', 'stdio','ipc', 'detaching', 'disconnecting', 'event exit' ];
    var got = _.strTable({ data, dim, style, topHead, colWidth : 18 });

    var exp =
`
╔════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║       mode              stdio              ipc            detaching       disconnecting      event exit    ║
╟────────────────────────────────────────────────────────────────────────────────────────────────────────────╢
║       spawn            inherit            false             false             false             true       ║
║       spawn            inherit            false             true              false             true       ║
║       spawn            inherit            true              false             false             true       ║
║       spawn            inherit            true              true              false             true       ║
║       spawn             pipe              false             false             false             true       ║
║       spawn             pipe              false             true              false             true       ║
║       spawn             pipe              false             false             true              true       ║
║       spawn             pipe              false             true              true              true       ║
║       spawn             pipe              true              false             false             true       ║
║       spawn             pipe              true              true              false             true       ║
║       spawn             pipe              true              false             true              true       ║
║       spawn             pipe              true              true              true              true       ║
║       spawn            ignore             false             false             false             true       ║
║       spawn            ignore             false             true              false             true       ║
║       spawn            ignore             false             false             true              true       ║
║       spawn            ignore             false             true              true              true       ║
║       spawn            ignore             true              false             false             true       ║
║       spawn            ignore             true              true              false             true       ║
║       spawn            ignore             true              false             true              true       ║
║       spawn            ignore             true              true              true              true       ║
║       fork             inherit            true              false             false             true       ║
║       fork             inherit            true              true              false             true       ║
║       fork              pipe              true              false             false             true       ║
║       fork              pipe              true              true              false             true       ║
║       fork              pipe              true              false             true              true       ║
║       fork              pipe              true              true              true              true       ║
║       fork             ignore             true              false             false             true       ║
║       fork             ignore             true              true              false             true       ║
║       fork             ignore             true              false             true              true       ║
║       fork             ignore             true              true              true              true       ║
║       shell            inherit            false             false             false             true       ║
║       shell            inherit            false             true              false             true       ║
║       shell             pipe              false             false             false             true       ║
║       shell             pipe              false             true              false             true       ║
║       shell             pipe              false             false             true              true       ║
║       shell             pipe              false             true              true              true       ║
║       shell            ignore             false             false             false             true       ║
║       shell            ignore             false             true              false             true       ║
║       shell            ignore             false             false             true              true       ║
║       shell            ignore             false             true              true              true       ║
╚════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
`
    test.equivalent( got.result, exp );

    console.log( got.result )
    return null;
  })

  return a.ready;

  /* - */

  function run( mode, stdio, ipc, detaching, disconnecting )
  {
    let ready = new _.Consequence().take( null );

    if( detaching && stdio === 'inherit' ) /* remove if assert in start is removed */
    return ready;

    if( ipc && mode === 'shell' )
    return ready;

    if( !ipc && mode === 'fork' )
    return ready;

    let result = [ mode, stdio, ipc, disconnecting, detaching, false ];

    ready.then( () =>
    {
      let o =
      {
        execPath : mode === 'fork' ? 'program1.js' : 'node program1.js',
        currentPath : a.routinePath,
        outputPiping : 0,
        outputCollecting : 0,
        stdio,
        mode,
        ipc,
        detaching
      }

      test.case = _.toJs({ mode, stdio, ipc, disconnecting, detaching });

      _.process.start( o );

      o.conStart.thenGive( () =>
      {
        if( disconnecting )
        o.disconnect()
      })
      o.process.on( 'exit', () =>
      {
        result[ 5 ] = true;
      })

      return _.time.out( context.t1 * 3, () =>
      {
        test.is( !_.process.isAlive( o.process.pid ) );
        test.identical( result[ 5 ], true );
        data.push.apply( data, result );
        return null;
      })
    })

    return ready;
  }

  /* - */

  function program1()
  {
    setTimeout( () => {}, context.t1 );
  }
}

startEventExit.timeOut = 300000;
startEventExit.description =
`
Check if exit event is called.
`

//

/* qqq for Yevhen : implement for other modes */
function startDetachingChildExitsAfterParent( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppParentPath = a.path.nativize( a.program( testAppParent ) );
  let testAppChildPath = a.path.nativize( a.program( testAppChild ) );
  let testFilePath = a.abs( a.routinePath, 'testFile' );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'parent disconnects detached child process and exits, child contiues to work'
    let o =
    {
      execPath : 'node testAppParent.js',
      mode : 'spawn',
      stdio : 'pipe',
      outputPiping : 1,
      outputCollecting : 1,
      currentPath : a.routinePath,
      detaching : 0,
      ipc : 1,
    }
    let con = _.process.start( o );

    let childPid;

    o.process.on( 'message', ( e ) =>
    {
      childPid = _.numberFrom( e );
    })

    o.conTerminate.then( ( op ) =>
    {
      test.will = 'parent is dead, detached child is still running'
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( _.process.isAlive( childPid ) );
      return _.time.out( 10000 ); /* zzz */
    })

    o.conTerminate.then( () =>
    {
      let childPid2 = a.fileProvider.fileRead( testFilePath );
      childPid2 = _.numberFrom( childPid2 )
      test.is( !_.process.isAlive( childPid2 ) );
      test.identical( childPid, childPid2 )
      return null;
    })

    return o.conTerminate;
  })

  /*  */

  return a.ready;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let o =
    {
      execPath : 'node testAppChild.js',
      stdio : 'ignore',
      outputPiping : 0,
      outputCollecting : 0,
      detaching : true,
      mode : 'spawn',
    }

    _.process.start( o );

    process.send( o.process.pid );

    _.time.out( 1000, () => o.disconnect() );
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' );

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' );
    })
  }
}

startDetachingChildExitsAfterParent.description =
`
Parent starts child process in detached mode and disconnects it.
Child process continues to work for at least 5 seconds after parent exits.
After 5 seconds child process creates test file in working directory and exits.
`

//

/* qqq for Yevhen : implement for other modes */
function startDetachingChildExitsBeforeParent( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppParentPath = a.path.nativize( a.program( testAppParent ) );
  let testAppChildPath = a.path.nativize( a.program( testAppChild ) );

  let testFilePath = a.abs( a.routinePath, 'testFile' );

  /* */

  a.ready

  .then( () =>
  {
    let o =
    {
      execPath : 'node testAppParent.js',
      mode : 'spawn',
      outputCollecting : 1,
      currentPath : a.routinePath,
      ipc : 1,
    }
    _.process.start( o );

    let child;
    let onChildTerminate = new _.Consequence();

    o.process.on( 'message', ( e ) =>
    {
      child = e;
      onChildTerminate.take( e );
    })

    onChildTerminate.then( () =>
    {
      let childPid = a.fileProvider.fileRead( testFilePath );
      test.is( _.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( _.numberFrom( childPid ) ) );
      return null;
    })

    o.conTerminate.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );

      test.will = 'parent and chid are dead';

      test.identical( child.err, undefined );
      test.identical( child.exitCode, 0 );
      test.identical( child.exitSignal, null );
      test.identical( child.exitReason, 'normal' );
      test.identical( child.ended, true );
      test.identical( child.state, 'terminated' );

      test.is( !_.process.isAlive( o.process.pid ) );
      test.is( !_.process.isAlive( child.pid ) );

      test.is( a.fileProvider.fileExists( testFilePath ) );
      let childPid = a.fileProvider.fileRead( testFilePath );
      childPid = _.numberFrom( childPid )
      test.is( !_.process.isAlive( childPid ) );

      test.identical( child.pid, childPid );

      return null;
    })

    return _.Consequence.AndKeep( onChildTerminate, o.conTerminate );
  })

  /*  */

  return a.ready;

  /* - */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let o =
    {
      execPath : 'node testAppChild.js',
      stdio : 'ignore',
      outputPiping : 0,
      outputCollecting : 0,
      detaching : true,
      mode : 'spawn',

    }

    _.process.start( o );

    o.conTerminate.finally( ( err, op ) =>
    {
      process.send({ exitCode : op.exitCode, err, pid : o.process.pid });
      return null;
    })

    _.time.out( 5000, () =>
    {
      console.log( 'Parent process end' )
    });
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 1000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }

}

startDetachingChildExitsBeforeParent.description =
`
Parent starts child process in detached mode and registers callback to wait for child process.
Child process creates test file after 1 second and exits.
Callback in parent recevies message. Parent exits.
`

//

function startDetachingDisconnectedEarly( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( mode ) ) );
  return a.ready;

  function run( mode )
  {
    let ready = _.Consequence().take( null );
    let track = [];

    ready
    .then( () =>
    {
      test.case = `detaching on, disconnected forked child, mode:${mode}`;
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 1,
      }

      let result = _.process.start( o );

      test.identical( o.ready.resourcesCount(), 0 );
      test.identical( o.ready.errorsCount(), 0 );
      test.identical( o.ready.competitorsCount(), 0 );
      test.identical( o.conStart.resourcesCount(), 1 );
      test.identical( o.conStart.errorsCount(), 0 );
      test.identical( o.conStart.competitorsCount(), 0 );
      test.identical( o.conDisconnect.resourcesCount(), 0 );
      test.identical( o.conDisconnect.errorsCount(), 0 );
      test.identical( o.conDisconnect.competitorsCount(), 0 );
      test.identical( o.conTerminate.resourcesCount(), 0 );
      test.identical( o.conTerminate.errorsCount(), 0 );
      test.identical( o.conTerminate.competitorsCount(), 0 );

      test.identical( o.state, 'started' );
      test.is( o.conStart !== result );
      test.is( _.consequenceIs( o.conStart ) )

      test.identical( o.state, 'started' );
      o.disconnect();
      test.identical( o.state, 'disconnected' );

      o.conStart.finally( ( err, op ) =>
      {
        track.push( 'conStart' );
        test.identical( err, undefined );
        test.identical( op, o );
        test.is( _.process.isAlive( o.process.pid ) );
        return null;
      })

      o.conDisconnect.finally( ( err, op ) =>
      {
        track.push( 'conDisconnect' );
        test.identical( err, undefined );
        test.identical( op, o );
        test.is( _.process.isAlive( o.process.pid ) )
        return null;
      })

      o.conTerminate.finally( ( err, op ) =>
      {
        track.push( 'conTerminate' );
        test.identical( err, undefined );
        return null;
      })

      result = _.time.out( 5000, () =>
      {
        test.identical( o.state, 'disconnected' );
        test.identical( o.ended, true );
        test.identical( track, [ 'conStart', 'conDisconnect' ] );
        test.is( !_.process.isAlive( o.process.pid ) )
        o.conTerminate.cancel();
        return null;
      })

      return _.Consequence.AndTake( o.conStart, result );
    })

    /* */

    return ready;
  }

  /* */

  function program1()
  {
    console.log( 'program1:begin' );
    setTimeout( () => { console.log( 'program1:end' ) }, 2000 );
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
  }
}

startDetachingDisconnectedEarly.description =
`
Parent starts child process in detached mode and disconnects it right after start.
Child process creates test file after 2 second and stays alive.
conStart recevies message when process starts.
conDisconnect recevies message on disconnect which happen without delay.
conTerminate does not recevie an message.
Test routine waits for few seconds and checks if child is alive.
ProcessWatched should not throw any error.
`

//

function startDetachingDisconnectedLate( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( mode ) ) );
  return a.ready;

  function run( mode )
  {
    let ready = _.Consequence().take( null );
    let track = [];

    ready
    .then( () =>
    {
      test.case = `detaching on, disconnected forked child, mode:${mode}`;
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 1,
      }

      let result = _.process.start( o );

      test.identical( o.ready.resourcesCount(), 0 );
      test.identical( o.ready.errorsCount(), 0 );
      test.identical( o.ready.competitorsCount(), 0 );
      test.identical( o.conStart.resourcesCount(), 1 );
      test.identical( o.conStart.errorsCount(), 0 );
      test.identical( o.conStart.competitorsCount(), 0 );
      test.identical( o.conDisconnect.resourcesCount(), 0 );
      test.identical( o.conDisconnect.errorsCount(), 0 );
      test.identical( o.conDisconnect.competitorsCount(), 0 );
      test.identical( o.conTerminate.resourcesCount(), 0 );
      test.identical( o.conTerminate.errorsCount(), 0 );
      test.identical( o.conTerminate.competitorsCount(), 0 );

      test.identical( o.state, 'started' );

      _.time.begin( 1000, () =>
      {
        test.identical( o.state, 'started' );
        o.disconnect();
        test.identical( o.state, 'disconnected' );
      });

      test.is( o.conStart !== result );
      test.is( _.consequenceIs( o.conStart ) )

      o.conStart.finally( ( err, op ) =>
      {
        track.push( 'conStart' );
        test.identical( err, undefined );
        test.identical( op, o );
        test.is( _.process.isAlive( o.process.pid ) )
        return null;
      })

      o.conDisconnect.finally( ( err, op ) =>
      {
        track.push( 'conDisconnect' );
        test.identical( err, undefined );
        test.identical( op, o );
        test.is( _.process.isAlive( o.process.pid ) )
        return null;
      })

      o.conTerminate.finally( ( err, op ) =>
      {
        track.push( 'conTerminate' );
        test.identical( err, undefined );
        return null;
      })

      result = _.time.out( 5000, () =>
      {
        test.identical( o.state, 'disconnected' );
        test.identical( o.ended, true );
        test.identical( track, [ 'conStart', 'conDisconnect' ] );
        test.is( !_.process.isAlive( o.process.pid ) )
        o.conTerminate.cancel();
        return null;
      })

      return _.Consequence.AndTake( o.conStart, result );
    })

    /* */

    return ready;
  }

  /* */

  function program1()
  {
    console.log( 'program1:begin' );
    setTimeout( () => { console.log( 'program1:end' ) }, 2000 );
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
  }
}

startDetachingDisconnectedLate.description =
`
Parent starts child process in detached mode and disconnects after short delay.
Child process creates test file after 2 second and stays alive.
conStart recevies message when process starts.
conDisconnect recevies message on disconnect which happen with short delay.
conTerminate does not recevie an message.
Test routine waits for few seconds and checks if child is alive.
ProcessWatched should not throw any error.
`

//

/* qqq for Yevhen : implement for other modes */
function startDetachingChildExistsBeforeParentWaitForTermination( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppChildPath = a.path.nativize( a.program( testAppChild ) );

  a.ready

  .then( () =>
  {
    test.case = 'detaching on, disconnected forked child'
    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      stdio : 'ignore',
      outputPiping : 0,
      outputCollecting : 0,
      currentPath : a.routinePath,
      detaching : 1
    }

    _.process.start( o );

    o.conTerminate.finally( ( err, op ) =>
    {
      test.identical( err, undefined );
      test.identical( op, o );
      test.is( !_.process.isAlive( o.process.pid ) )
      return null;
    })

    return o.conTerminate;
  })

  /* */

  return a.ready;

  /* */

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    var args = _.process.args();

    _.time.out( 2000, () =>
    {
      console.log( 'Child process end' )
      return null;
    })
  }

}

//

startDetachingChildExistsBeforeParentWaitForTermination.description =
`
Parent starts child process in detached mode.
Test routine waits until o.conTerminate resolves message about termination of the child process.
`

//

/* qqq for Yevhen : implement for other modes */
function startDetachingEndCompetitorIsExecuted( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppChildPath = a.program( testAppChild );

  a.ready

  .then( () =>
  {
    test.case = 'detaching on, disconnected forked child'
    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      stdio : 'ignore',
      outputPiping : 0,
      outputCollecting : 0,
      currentPath : a.routinePath,
      detaching : 1
    }

    let result = _.process.start( o );

    test.is( o.conStart !== result );
    test.is( _.consequenceIs( o.conStart ) )
    test.is( _.consequenceIs( o.conTerminate ) )

    o.conStart.finally( ( err, op ) =>
    {
      track.push( 'conStart' );
      test.identical( o.ended, false );
      test.identical( err, undefined );
      test.identical( op, o );
      test.is( _.process.isAlive( o.process.pid ) );
      return null;
    })

    o.conTerminate.finally( ( err, op ) =>
    {
      track.push( 'conTerminate' );
      test.identical( o.ended, true );
      test.identical( err, undefined );
      test.identical( op, o );
      test.identical( track, [ 'conStart', 'conTerminate' ] )
      test.is( !_.process.isAlive( o.process.pid ) )
      return null;
    })

    return _.Consequence.AndTake( o.conStart, o.conTerminate );
  })

  /* */

  return a.ready;

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    var args = _.process.args();

    _.time.out( 2000, () =>
    {
      console.log( 'Child process end' )
      return null;
    })
  }

}

startDetachingEndCompetitorIsExecuted.description =

`Parent starts child process in detached mode.
Consequence conStart recevices message when process starts.
Consequence conTerminate recevices message when process ends.
o.ended is false when conStart callback is executed.
o.ended is true when conTerminate callback is executed.
`

//

/* qqq for Vova : remove negligence. name test cases carefully */
function startDetachingTerminationBegin( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testFilePath = a.abs( a.routinePath, 'testFile' );
  let modes = [ 'fork', 'spawn', 'shell' ];

  modes.forEach( ( mode ) =>
  {
    a.ready.then( () =>
    {
      a.fileProvider.filesDelete( a.routinePath );
      let locals =
      {
        toolsPath : _.path.nativize( _.module.toolsPathGet() ),
        mode,
      }
      a.path.nativize( a.program({ routine : testAppParent, locals }) );
      a.path.nativize( a.program( testAppChild ) );
      return null;
    })

    a.ready.tap( () => test.open( mode ) );
    a.ready.then( () => run( mode ) );
    a.ready.tap( () => test.close( mode ) );
  });

  return a.ready;

  /* - */

  function run( mode )
  {
    let ready = new _.Consequence().take( null )

    /*  */

    ready.then( () =>
    {
      test.case = 'process termination begins after short delay, detached process should continue to work after parent death 1';

      a.fileProvider.filesDelete( testFilePath );
      a.fileProvider.dirMakeForFile( testFilePath );

      let o =
      {
        execPath : 'node testAppParent.js stdio : ignore outputPiping : 0 outputCollecting : 0',
        mode : 'spawn',
        outputCollecting : 1,
        currentPath : a.routinePath,
        ipc : 1,
      }
      let con = _.process.start( o );

      let data;

      o.process.on( 'message', ( e ) =>
      {
        data = e;
        data.childPid = _.numberFrom( data.childPid );
      })

      con.then( ( op ) =>
      {
        test.will = 'parent is dead, child is still alive';
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( !_.process.isAlive( op.process.pid ) );
        test.is( _.process.isAlive( data.childPid ) );
        return _.time.out( context.t2 * 2 );
      })

      con.then( () =>
      {
        test.will = 'both dead';

        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( data.childPid ) );

        test.is( a.fileProvider.fileExists( testFilePath ) );
        let childPid = a.fileProvider.fileRead( testFilePath );
        childPid = _.numberFrom( childPid );
        console.log(  childPid );
        if( mode !== 'shell' )
        test.identical( data.childPid, childPid );

        return null;
      })

      return con;
    })

    /*  */

    ready.then( () =>
    {
      test.case = 'process termination begins after short delay, detached process should continue to work after parent death 2';

      a.fileProvider.filesDelete( testFilePath );
      a.fileProvider.dirMakeForFile( testFilePath );

      let o =
      {
        execPath : `node testAppParent.js stdio : ignore ${ mode === 'shell' ? '' : 'ipc:1'} outputPiping : 0 outputCollecting : 0`,
        mode : 'spawn',
        outputCollecting : 1,
        currentPath : a.routinePath,
        ipc : 1,
      }
      let con = _.process.start( o );

      let data;

      o.process.on( 'message', ( e ) =>
      {
        data = e;
        data.childPid = _.numberFrom( data.childPid );
      })

      con.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.will = 'parent is dead, child is still alive';
        test.is( !_.process.isAlive( op.process.pid ) );
        test.is( _.process.isAlive( data.childPid ) );
        return _.time.out( context.t2 * 2 );
      })

      con.then( () =>
      {
        test.will = 'both dead';

        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( data.childPid ) );

        test.is( a.fileProvider.fileExists( testFilePath ) );
        let childPid = a.fileProvider.fileRead( testFilePath );
        childPid = _.numberFrom( childPid );
        if( mode !== 'shell' )
        test.identical( data.childPid, childPid );

        return null;
      })

      return con;
    })

    /*  */

    ready.then( () =>
    {
      test.case = 'process termination begins after short delay, detached process should continue to work after parent death 3';

      a.fileProvider.filesDelete( testFilePath );
      a.fileProvider.dirMakeForFile( testFilePath );

      let o =
      {
        execPath : 'node testAppParent.js stdio : pipe',
        mode : 'spawn',
        outputCollecting : 1,
        currentPath : a.routinePath,
        ipc : 1,
      }
      let con = _.process.start( o );

      let data;

      o.process.on( 'message', ( e ) =>
      {
        data = e;
        data.childPid = _.numberFrom( data.childPid );
      })

      con.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.will = 'parent is dead, child is still alive';
        test.is( !_.process.isAlive( op.process.pid ) );
        test.is( _.process.isAlive( data.childPid ) );
        return _.time.out( context.t2 * 2 );
      })

      con.then( () =>
      {
        test.will = 'both dead';

        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( data.childPid ) );

        test.is( a.fileProvider.fileExists( testFilePath ) );
        let childPid = a.fileProvider.fileRead( testFilePath );
        childPid = _.numberFrom( childPid );
        if( mode !== 'shell' )
        test.identical( data.childPid, childPid )

        return null;
      })

      return con;
    })

    /*  */

    ready.then( () =>
    {
      test.case = 'process termination begins after short delay, detached process should continue to work after parent death 4';

      a.fileProvider.filesDelete( testFilePath );
      a.fileProvider.dirMakeForFile( testFilePath );

      let o =
      {
        execPath : `node testAppParent.js stdio : pipe ${ mode === 'shell' ? '' : 'ipc:1'}`,
        mode : 'spawn',
        outputCollecting : 1,
        currentPath : a.routinePath,
        ipc : 1,
      }
      let con = _.process.start( o );

      let data;

      o.process.on( 'message', ( e ) =>
      {
        data = e;
        data.childPid = _.numberFrom( data.childPid );
      })

      con.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.will = 'parent is dead, child is still alive';
        test.is( !_.process.isAlive( op.process.pid ) );
        test.is( _.process.isAlive( data.childPid ) );
        return _.time.out( context.t2 * 2 );
      })

      con.then( () =>
      {
        test.will = 'both dead';

        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( data.childPid ) );

        test.is( a.fileProvider.fileExists( testFilePath ) );
        let childPid = a.fileProvider.fileRead( testFilePath );
        childPid = _.numberFrom( childPid );
        if( mode !== 'shell' )
        test.identical( data.childPid, childPid )

        return null;
      })

      return con;
    })

    return ready;
  }

  /*  */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let args = _.process.args();

    let o =
    {
      execPath : mode === 'fork' ? 'testAppChild.js' : 'node testAppChild.js',
      mode,
      detaching : true,
    }

    _.mapExtend( o, args.map );

    _.process.start( o );

    console.log( o.process.pid )

    process.send({ childPid : o.process.pid });

    o.conStart.thenGive( () =>
    {
      _.procedure.terminationBegin();
    })
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    console.log( 'Child process start', process.pid )
    _.time.out( 2000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

startDetachingTerminationBegin.timeOut = 180000;

//

/* qqq for Yevhen : implement for other modes */
function startDetachingThrowing( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppChildPath = a.program( testAppChild );

  /* */

  test.is( true );

  if( !Config.debug )
  return;

  var o =
  {
    execPath : 'node testAppChild.js',
    mode : 'spawn',
    stdio : 'inherit',
    currentPath : a.routinePath,
    detaching : 1
  }
  test.shouldThrowErrorSync( () => _.process.start( o ) )

  /* */

  var o =
  {
    execPath : 'node testAppChild.js',
    mode : 'shell',
    stdio : 'inherit',
    currentPath : a.routinePath,
    detaching : 1
  }
  test.shouldThrowErrorSync( () => _.process.start( o ) )

  /* */

  var o =
  {
    execPath : 'testAppChild.js',
    mode : 'fork',
    stdio : 'inherit',
    currentPath : a.routinePath,
    detaching : 1
  }
  test.shouldThrowErrorSync( () => _.process.start( o ) )

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    console.log( 'Child process start' )

    _.time.out( 5000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

//

function startNjsDetachingChildThrowing( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let track = [];
  let testAppChildPath = a.program( testAppChild );

  /* */

  test.case = 'detached child throws error, conTerminate receives resource with error';

  let o =
  {
    execPath : 'testAppChild.js',
    outputCollecting : 1,
    stdio : 'pipe',
    detaching : 1,
    applyingExitCode : 0,
    throwingExitCode : 0,
    outputPiping : 0,
    currentPath : a.routinePath,
  }

  _.process.startNjs( o );

  o.conTerminate.then( ( op ) =>
  {
    track.push( 'conTerminate' );
    test.notIdentical( op.exitCode, 0 );
    test.identical( op.ended, true );
    test.is( _.strHas( op.output, 'Child process error' ) );
    test.identical( o.exitCode, op.exitCode );
    test.identical( o.output, op.output );
    test.identical( track, [ 'conTerminate' ] )
    return null;
  })

  return o.conTerminate;

  /* - */

  function testAppChild()
  {
    setTimeout( () =>
    {
      throw new Error( 'Child process error' );
    }, 1000)
  }

}

// --
// on
// --

function startOnStart( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppChildPath = a.path.nativize( a.program( testAppChild ) );
  let track = [];

  let modes = [ 'fork', 'spawn', 'shell' ];

  modes.forEach( ( mode ) =>
  {
    a.ready.tap( () => test.open( mode ) );
    a.ready.then( () => run( mode ) );
    a.ready.tap( () => test.close( mode ) );
  });

  return a.ready;

  /* */

  function run( mode )
  {
    let fork = mode === 'fork';
    let ready = new _.Consequence().take( null )

    /* */

    .then( () =>
    {
      test.case = 'detaching off, no errors'
      let o =
      {
        execPath : !fork ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 0
      }

      let result = _.process.start( o );

      test.notIdentical( o.conStart, result );
      test.is( _.consequenceIs( o.conStart ) )

      o.conStart.finally( ( err, op ) =>
      {
        test.identical( err, undefined );
        test.identical( op, o );
        test.is( _.process.isAlive( o.process.pid ) );
        return null;
      })

      result.then( ( op ) =>
      {
        test.identical( o, op );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })

      return _.Consequence.AndTake( o.conStart, result );
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching off, error on spawn'
      let o =
      {
        execPath : 'unknownScript.js',
        mode,
        stdio : [ null, 'something', null ],
        currentPath : a.routinePath,
        detaching : 0
      }

      let result = _.process.start( o );

      test.notIdentical( o.conStart, result );
      test.is( _.consequenceIs( o.conStart ) )

      return test.shouldThrowErrorAsync( o.conTerminate );
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching off, error on spawn, no callback for conStart'
      let o =
      {
        execPath : 'unknownScript.js',
        mode,
        stdio : [ null, 'something', null ],
        currentPath : a.routinePath,
        detaching : 0
      }

      let result = _.process.start( o );

      test.notIdentical( o.conStart, result );
      test.is( _.consequenceIs( o.conStart ) )

      return test.shouldThrowErrorAsync( o.conTerminate );
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching on, conStart and result are same and give resource on start'
      let o =
      {
        execPath : !fork ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 1
      }

      let result = _.process.start( o );

      test.is( o.conStart !== result );
      test.is( _.consequenceIs( o.conStart ) )

      o.conStart.then( ( op ) =>
      {
        test.identical( o, op );
        test.identical( op.exitCode, null );
        test.identical( op.ended, false );
        test.identical( op.exitSignal, null );
        return null;
      })

      return _.Consequence.AndTake( o.conStart, o.conTerminate );
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching on, error on spawn'
      let o =
      {
        execPath : 'unknownScript.js',
        mode,
        stdio : [ 'ignore', 'ignore', 'ignore', null ],
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 1
      }

      let result = _.process.start( o );

      test.is( o.conStart !== result );
      test.is( _.consequenceIs( o.conStart ) )

      result = test.shouldThrowErrorAsync( o.conTerminate );

      result.then( () => _.time.out( 2000 ) )
      result.then( () =>
      {
        test.identical( o.conTerminate.resourcesCount(), 0 );
        return null;
      })

      return result;
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching on, disconnected child';
      track = [];
      let o =
      {
        execPath : !fork ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 1
      }

      let result = _.process.start( o );

      test.is( o.conStart !== result );

      o.conStart.finally( ( err, op ) =>
      {
        track.push( 'conStart' );
        test.identical( err, undefined );
        test.identical( op, o );
        test.is( _.process.isAlive( o.process.pid ) )
        test.identical( o.state, 'started' );
        o.disconnect();
        return null;
      })

      o.conDisconnect.finally( ( err, op ) =>
      {
        track.push( 'conDisconnect' );
        test.identical( err, undefined );
        test.identical( op, o );
        test.identical( o.state, 'disconnected' );
        test.is( _.process.isAlive( o.process.pid ) );
        return null;
      })

      o.conTerminate.finally( ( err, op ) =>
      {
        track.push( 'conTerminate' );
        test.identical( err, undefined );
        return null;
      })

      let ready = _.time.out( 5000, () =>
      {
        test.identical( track, [ 'conStart', 'conDisconnect' ] );
        o.conTerminate.cancel();
      })

      return _.Consequence.AndTake( o.conStart, o.conDisconnect, ready );
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching on, disconnected forked child'
      let o =
      {
        execPath : !fork ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 1
      }

      let result = _.process.start( o );

      test.is( o.conStart !== result );

      o.conStart.finally( ( err, op ) =>
      {
        test.identical( err, undefined );
        test.identical( op, o );
        test.identical( o.state, 'started' )
        test.is( _.process.isAlive( o.process.pid ) )
        o.disconnect();
        return null;
      })

      o.conDisconnect.finally( ( err, op ) =>
      {
        test.identical( err, undefined );
        test.identical( op, o );
        test.identical( o.state, 'disconnected' )
        test.is( _.process.isAlive( o.process.pid ) )
        return null;
      })

      result = _.time.out( 2000 + context.t2, () =>
      {
        test.is( !_.process.isAlive( o.process.pid ) )
        test.identical( o.exitCode, null );
        test.identical( o.exitSignal, null );
        test.identical( o.conTerminate.resourcesCount(), 0 );
        return null;
      })

      return _.Consequence.AndTake( o.conStart, o.conDisconnect, result );
    })

    /* */

    return ready;
  }


  /* */

  function testAppChild()
  {
    console.log( 'Child process begin' );

    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    var args = _.process.args();

    _.time.out( 2000, () =>
    {
      console.log( 'Child process end' );
      return null;
    })
  }

}

startOnStart.timeOut = 120000;

//

function startOnTerminate( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppChildPath = a.path.nativize( a.program( testAppChild ) );
  let modes = [ 'fork', 'spawn', 'shell' ];

  modes.forEach( ( mode ) =>
  {
    a.ready.tap( () => test.open( mode ) );
    a.ready.then( () => run( mode ) );
    a.ready.tap( () => test.close( mode ) );
  });

  return a.ready;

  /* */

  function run( mode )
  {
    let ready = new _.Consequence().take( null )

    .then( () =>
    {
      test.case = 'detaching off'
      let o =
      {
        execPath : mode !== 'fork' ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 0
      }

      let result = _.process.start( o );

      test.is( o.conTerminate !== result );

      result.then( ( op ) =>
      {
        test.identical( o, op );
        test.identical( op.state, 'terminated' );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        return null;
      })

      return result;
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching off, disconnect'
      let o =
      {
        execPath : mode !== 'fork' ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        detaching : 0
      }
      let track = [];

      let result = _.process.start( o );

      o.disconnect();

      test.is( o.conTerminate !== result );

      o.conTerminate.then( ( op ) =>
      {
        track.push( 'conTerminate' );
        test.identical( o, op );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })

      return _.time.out( 2000 + context.t2, () =>
      {
        test.identical( o.state, 'disconnected' );
        test.identical( o.ended, true );
        test.identical( track, [] );
        test.identical( o.conTerminate.resourcesCount(), 0 );
        test.identical( o.conTerminate.errorsCount(), 0 );
        test.identical( o.conTerminate.competitorsCount(), 1 );
        test.is( !_.process.isAlive( o.process.pid ) );
        o.conTerminate.cancel();
        return null;
      });
    })

    /* */

    .then( () =>
    {
      test.case = 'detaching, child not disconnected, parent waits for child to exit'
      let conTerminate = new _.Consequence();
      let o =
      {
        execPath : mode !== 'fork' ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        conTerminate,
        detaching : 1
      }

      let result = _.process.start( o );

      test.is( result !== o.conStart );
      test.notIdentical( conTerminate, result );
      test.identical( conTerminate, o.conTerminate );

      conTerminate.then( ( op ) =>
      {
        test.identical( o, op );
        test.identical( op.state, 'terminated' );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        return null;
      })

      return conTerminate;
    })

    /* */

    .then( () =>
    {
      test.case = 'detached, child disconnected before it termination'
      let conTerminate = new _.Consequence();
      let o =
      {
        execPath : mode !== 'fork' ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'pipe',
        currentPath : a.routinePath,
        conTerminate,
        detaching : 1
      }
      let track = [];

      let result = _.process.start( o );
      test.is( result !== o.conStart );
      test.is( result !== o.conTerminate );
      test.identical( conTerminate, o.conTerminate );

      _.time.out( context.t1, () => o.disconnect() );

      conTerminate.then( ( op ) =>
      {
        track.push( 'conTerminate' );
        test.identical( o, op );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })

      return _.time.out( 2000 + context.t2, () => /* 3000 is not enough */
      {
        test.identical( track, [] );
        test.identical( o.state, 'disconnected' );
        test.identical( o.ended, true );
        test.identical( o.conTerminate.resourcesCount(), 0 );
        test.identical( o.conTerminate.errorsCount(), 0 );
        test.identical( o.conTerminate.competitorsCount(), 1 );
        test.is( !_.process.isAlive( o.process.pid ) );
        o.conTerminate.cancel();
        return null;
      });

    })

    /* */

    .then( () =>
    {
      test.case = 'detached, child disconnected after it termination'
      let conTerminate = new _.Consequence();
      let o =
      {
        execPath : mode !== 'fork' ? 'node testAppChild.js' : 'testAppChild.js',
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        conTerminate,
        detaching : 1
      }

      let result = _.process.start( o );

      test.is( result !== o.conStart );
      test.is( result !== o.conTerminate )
      test.identical( conTerminate, o.conTerminate )

      conTerminate.then( ( op ) =>
      {
        test.identical( op.state, 'terminated' );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        op.disconnect();
        return op;
      })

      return test.mustNotThrowError( conTerminate )
      .then( ( op ) =>
      {
        test.identical( o, op );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })
    })

    /* */

    .then( () =>
    {
      test.case = 'detached, not disconnected child throws error during execution'
      let conTerminate = new _.Consequence();
      let o =
      {
        execPath : mode !== 'fork' ? 'node testAppChild.js' : 'testAppChild.js',
        args : [ 'throwing:1' ],
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        conTerminate,
        throwingExitCode : 0,
        detaching : 1
      }

      let result = _.process.start( o );

      test.is( result !== o.conStart );
      test.is( result !== o.conTerminate );
      test.identical( conTerminate, o.conTerminate );

      conTerminate.then( ( op ) =>
      {
        test.identical( o, op );
        test.identical( op.state, 'terminated' );
        test.identical( op.ended, true );
        test.identical( op.error, null );
        test.notIdentical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        return null;
      })

      return conTerminate;
    })

    /* */

    .then( () =>
    {
      test.case = 'detached, disconnected child throws error during execution'
      let conTerminate = new _.Consequence();
      let o =
      {
        execPath : mode !== 'fork' ? 'node testAppChild.js' : 'testAppChild.js',
        args : [ 'throwing:1' ],
        mode,
        stdio : 'ignore',
        outputPiping : 0,
        outputCollecting : 0,
        currentPath : a.routinePath,
        conTerminate,
        throwingExitCode : 0,
        detaching : 1
      }
      let track = [];

      let result = _.process.start( o );

      test.is( result !== o.conStart );
      test.is( result !== o.conTerminate );
      test.identical( conTerminate, o.conTerminate );

      o.disconnect();

      conTerminate.then( () =>
      {
        track.push( 'conTerminate' );
        return null;
      })

      return _.time.out( 2000 + context.t2, () => /* 3000 is not enough */
      {
        test.identical( track, [] );
        test.identical( o.state, 'disconnected' );
        test.identical( o.ended, true );
        test.identical( o.error, null );
        test.identical( o.exitCode, null );
        test.identical( o.exitSignal, null );

        test.identical( o.conTerminate.resourcesCount(), 0 );
        test.identical( o.conTerminate.errorsCount(), 0 );
        test.identical( o.conTerminate.competitorsCount(), 1 );
        test.is( !_.process.isAlive( o.process.pid ) );
        o.conTerminate.cancel();
        return null;
      });
    })

    /* */

    return ready;
  }

  /* - */

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    var args = _.process.args();

    _.time.out( 2000, () =>
    {
      if( args.map.throwing )
      throw _.err( 'Child process error' );
      console.log( 'Child process end' )
      return null;
    })
  }
}

startOnTerminate.timeOut = 120000;

//

function startNoEndBug1( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppChildPath = a.program( testAppChild );

  a.ready

  /* */

  .then( () =>
  {
    test.case = 'detaching on, error on spawn'
    let o =
    {
      execPath : 'testAppChild.js',
      mode : 'fork',
      stdio : [ 'ignore', 'ignore', 'ignore', null ],
      currentPath : a.routinePath,
      detaching : 1
    }

    let result = _.process.start( o );

    test.is( o.conStart !== result );
    test.is( _.consequenceIs( o.conStart ) )

    result = test.shouldThrowErrorAsync( o.conTerminate );

    result.then( () => _.time.out( 2000 ) )
    result.then( () =>
    {
      test.identical( o.conTerminate.resourcesCount(), 0 );
      return null;
    })

    return result;
  })

  /* */

  return a.ready;

  /* */

  function testAppChild()
  {
    _.include( 'wProcess' );
    var args = _.process.args();
    _.time.out( 2000, () =>
    {
      console.log( 'Child process end' )
      return null;
    })
  }

}

startNoEndBug1.description =
`
Parent starts child process in detached mode.
ChildProcess throws an error on spawn.
conStart receives error message.
Parent should not try to disconnect the child.
`

//

function startWithDelayOnReady( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let time1 = _.time.now();

  a.ready.timeOut( 1000 );

  /* */

  let options =
  {
    execPath : 'node',
    args : programPath,
    currentPath : a.currentPath,
    throwingExitCode : 1,
    applyingExitCode : 0,
    inputMirroring : 1,
    outputCollecting : 1,
    stdio : 'pipe',
    sync : 0,
    deasync : 0,
    ready : a.ready,
  }

  _.process.start( options );

  test.is( _.consequenceIs( options.conStart ) );
  test.is( _.consequenceIs( options.conDisconnect ) );
  test.is( _.consequenceIs( options.conTerminate ) );
  test.is( _.consequenceIs( options.ready ) );
  test.is( options.conStart !== options.ready );
  test.is( options.conDisconnect !== options.ready );
  test.is( options.conTerminate !== options.ready );

  options.conStart
  .then( ( op ) =>
  {
    test.is( options === op );
    test.identical( options.output, '' );
    test.identical( options.exitCode, null );
    test.identical( options.exitSignal, null );
    test.identical( options.process.exitCode, null );
    test.identical( options.process.signalCode, null );
    test.identical( options.ended, false );
    test.identical( options.exitReason, null );
    test.is( !!options.process );
    return null;
  });

  options.conTerminate
  .finally( ( err, op ) =>
  {
    test.identical( err, undefined );
    debugger;
    test.identical( op.output, 'program1:begin\nprogram1:end\n' );
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    return null;
  });

  /* */

  return a.ready;

  /* */

  function program1()
  {
    let _ = require( toolsPath );
    console.log( 'program1:begin' );
    setTimeout( () => { console.log( 'program1:end' ) }, 15000 );
  }

}

startWithDelayOnReady.description =
`
  - consequence conStart has delay
`

//

function startOnIsNotConsequence( test )
{
  let context = this;
  let track;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  // let modes = [ 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 0, 1, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 0, mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => run( 1, 1, mode ) ) );
  return a.ready;

  /* - */

  function run( sync, deasync, mode )
  {
    let con = _.Consequence().take( null );

    if( sync && !deasync && mode === 'fork' )
    return null;

    /* */

    con.then( () =>
    {
      test.case = `normal sync:${sync} deasync:${deasync} mode:${mode}`
      track = [];
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        mode,
        sync,
        deasync,
        conStart,
        conDisconnect,
        conTerminate,
        ready,
      }
      var returned = _.process.start( o );
      o.ready.finally( function( err, op )
      {
        track.push( 'returned' );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return op;
      })

      return _.time.out( context.t2, () =>
      {
        test.identical( track, [ 'conStart', 'conTerminate', 'ready', 'returned' ] );
      });
    })

    /* */

    con.then( () =>
    {
      test.case = `throwing sync:${sync} deasync:${deasync} mode:${mode}`
      track = [];
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        args : [ 'throwing' ],
        mode,
        conStart,
        conDisconnect,
        conTerminate,
        ready,
      }
      var returned = _.process.start( o );
      o.ready.finally( function( err, op )
      {
        track.push( 'returned' );
        test.is( _.errIs( err ) );
        test.identical( op, undefined );
        test.notIdentical( o.exitCode, 0 );
        test.identical( o.ended, true );
        _.errAttend( err );
        return null;
      })
      return _.time.out( context.t2, () =>
      {
        test.identical( track, [ 'conStart', 'conTerminate', 'ready', 'returned' ] );
      });
    })

    /* */

    con.then( () =>
    {
      test.case = `detaching sync:${sync} deasync:${deasync} mode:${mode}`
      track = [];
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        detaching : 1,
        mode,
        conStart,
        conDisconnect,
        conTerminate,
        ready,
      }
      var returned = _.process.start( o );
      o.ready.finally( function( err, op )
      {
        track.push( 'returned' );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return op;
      })

      return _.time.out( context.t2, () =>
      {
        test.identical( track, [ 'conStart', 'conTerminate', 'ready', 'returned' ] );
      });
    })

    /* */

    con.then( () =>
    {
      test.case = `disconnecting sync:${sync} deasync:${deasync} mode:${mode}`
      track = [];
      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        detaching : 1,
        mode,
        conStart,
        conDisconnect,
        conTerminate,
        ready,
      }
      var returned = _.process.start( o );
      o.disconnect();
      o.ready.finally( function( err, op )
      {
        track.push( 'returned' );
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        return op;
      })

      return _.time.out( context.t2, () =>
      {
        test.identical( track, [ 'conStart', 'conDisconnect', 'ready', 'returned' ] );
      });
    })

    /* */

    return con
  }

  function program1()
  {
    console.log( process.argv.slice( 2 ) );
    if( process.argv.slice( 2 ).join( ' ' ).includes( 'throwing' ) )
    throw 'Error1!'
  }

  function ready( err, arg )
  {
    track.push( 'ready' );
    if( err )
    throw err;
    return arg;
  }

  function conStart( err, arg )
  {
    track.push( 'conStart' );
    if( err )
    throw err;
    return arg;
  }

  function conTerminate( err, arg )
  {
    track.push( 'conTerminate' );
    if( err )
    throw err;
    return arg;
  }

  function conDisconnect( err, arg )
  {
    track.push( 'conDisconnect' );
    if( err )
    throw err;
    return arg;
  }

}

startOnIsNotConsequence.timeOut = 300000;

//

function startConcurrent( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( program1 ) );
  let counter = 0;
  let time = 0;
  let filePath = a.path.nativize( a.abs( a.routinePath, 'file.txt' ) );

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single';
    time = _.time.now();
    return null;
  })

  let singleOption =
  {
    execPath : 'node ' + testAppPath + ' 1000',
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  _.process.start( singleOption )
  .then( ( arg ) =>
  {

    test.identical( arg.exitCode, 0 );
    test.identical( arg.exitSignal, null );
    test.identical( arg.exitReason, 'normal' );
    test.identical( arg.ended, true );
    test.identical( arg.state, 'terminated' );
    test.is( singleOption === arg );
    test.is( _.strHas( arg.output, 'begin 1000' ) );
    test.is( _.strHas( arg.output, 'end 1000' ) );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single, execPath in array';
    time = _.time.now();
    return null;
  })

  let singleExecPathInArrayOptions =
  {
    execPath : [ 'node ' + testAppPath + ' 1000' ],
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  _.process.start( singleExecPathInArrayOptions )
  .then( ( arg ) =>
  {

    test.identical( arg.length, 1 );
    test.identical( arg[ 0 ].exitCode, 0 );
    test.identical( arg[ 0 ].exitSignal, null );
    test.identical( arg[ 0 ].exitReason, 'normal' );
    test.identical( arg[ 0 ].ended, true );
    test.identical( arg[ 0 ].state, 'terminated' );
    test.is( singleExecPathInArrayOptions !== arg[ 0 ] );
    test.is( _.strHas( arg[ 0 ].output, 'begin 1000' ) );
    test.is( _.strHas( arg[ 0 ].output, 'end 1000' ) );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single, error in ready';
    time = _.time.now();
    throw _.err( 'Error!' );
  })

  let singleErrorBeforeScalar =
  {
    execPath : 'node ' + testAppPath + ' 1000',
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  _.process.start( singleErrorBeforeScalar )
  .finally( ( err, arg ) =>
  {
    test.is( arg === undefined );
    test.is( _.errIs( err ) );
    test.identical( singleErrorBeforeScalar.exitCode, null );
    test.identical( singleErrorBeforeScalar.output, null );
    test.is( !a.fileProvider.fileExists( filePath ) );
    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single, error in ready';
    time = _.time.now();
    throw _.err( 'Error!' );
  })

  let singleErrorBefore =
  {
    execPath : [ 'node ' + testAppPath + ' 1000' ],
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  _.process.start( singleErrorBefore )
  .finally( ( err, arg ) =>
  {

    test.is( arg === undefined );
    test.is( _.errIs( err ) );
    test.identical( singleErrorBefore.exitCode, null );
    test.identical( singleErrorBefore.output, undefined );
    test.is( !a.fileProvider.fileExists( filePath ) );

    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, serial';
    time = _.time.now();
    return null;
  })

  let subprocessesOptionsSerial =
  {
    execPath :  [ 'node ' + testAppPath + ' 1000', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 0,
  }

  _.process.start( subprocessesOptionsSerial )
  .then( ( arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 1000 );
    test.le( spent, 5000 );

    test.identical( subprocessesOptionsSerial.exitCode, 0 );
    test.identical( subprocessesOptionsSerial.exitSignal, null );
    test.identical( subprocessesOptionsSerial.exitReason, 'normal' );
    test.identical( subprocessesOptionsSerial.ended, true );
    test.identical( subprocessesOptionsSerial.state, 'terminated' );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 0 );
    test.identical( arg[ 0 ].exitSignal, null );
    test.identical( arg[ 0 ].exitReason, 'normal' );
    test.identical( arg[ 0 ].ended, true );
    test.identical( arg[ 0 ].state, 'terminated' );
    test.is( _.strHas( arg[ 0 ].output, 'begin 1000' ) );
    test.is( _.strHas( arg[ 0 ].output, 'end 1000' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 10' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 10' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, serial, error, throwingExitCode : 1';
    time = _.time.now();
    return null;
  })

  let subprocessesError =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 0,
  }

  _.process.start( subprocessesError )
  .finally( ( err, arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesError.exitCode, 1 );
    test.is( _.errIs( err ) );
    test.is( arg === undefined );
    test.is( !a.fileProvider.fileExists( filePath ) );

    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, serial, error, throwingExitCode : 0';
    time = _.time.now();
    return null;
  })

  let subprocessesErrorNonThrowing =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 0,
    throwingExitCode : 0,
  }

  _.process.start( subprocessesErrorNonThrowing )
  .finally( ( err, arg ) =>
  {
    test.is( !err );

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesErrorNonThrowing.exitCode, 1 );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 1 );
    test.is( _.strHas( arg[ 0 ].output, 'begin x' ) );
    test.is( !_.strHas( arg[ 0 ].output, 'end x' ) );
    test.is( _.strHas( arg[ 0 ].output, 'Expects number' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 10' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 10' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, concurrent : 1, error, throwingExitCode : 1';
    time = _.time.now();
    return null;
  })

  let subprocessesErrorConcurrent =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
  }

  _.process.start( subprocessesErrorConcurrent )
  .finally( ( err, arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesErrorConcurrent.exitCode, 1 );
    test.is( _.errIs( err ) );
    test.is( arg === undefined );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, concurrent : 1, error, throwingExitCode : 0';
    time = _.time.now();
    return null;
  })

  let subprocessesErrorConcurrentNonThrowing =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
    throwingExitCode : 0,
  }

  _.process.start( subprocessesErrorConcurrentNonThrowing )
  .finally( ( err, arg ) =>
  {
    test.is( !err );

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesErrorConcurrentNonThrowing.exitCode, 1 );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 1 );
    test.is( _.strHas( arg[ 0 ].output, 'begin x' ) );
    test.is( !_.strHas( arg[ 0 ].output, 'end x' ) );
    test.is( _.strHas( arg[ 0 ].output, 'Expects number' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 10' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 10' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, concurrent : 1';
    time = _.time.now();
    return null;
  })

  let suprocessesConcurrentOptions =
  {
    execPath :  [ 'node ' + testAppPath + ' 1000', 'node ' + testAppPath + ' 100' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
  }

  _.process.start( suprocessesConcurrentOptions )
  .then( ( arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent )
    test.gt( spent, 1000 );
    test.le( spent, 5000 );

    test.identical( suprocessesConcurrentOptions.exitCode, 0 );
    test.identical( suprocessesConcurrentOptions.exitSignal, null );
    test.identical( suprocessesConcurrentOptions.exitReason, 'normal' );
    test.identical( suprocessesConcurrentOptions.ended, true );
    test.identical( suprocessesConcurrentOptions.state, 'terminated' );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 0 );
    test.identical( arg[ 0 ].exitSignal, null );
    test.identical( arg[ 0 ].exitReason, 'normal' );
    test.identical( arg[ 0 ].ended, true );
    test.identical( arg[ 0 ].state, 'terminated' );
    test.is( _.strHas( arg[ 0 ].output, 'begin 1000' ) );
    test.is( _.strHas( arg[ 0 ].output, 'end 1000' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 100' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 100' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'args';
    time = _.time.now();
    return null;
  })

  let suprocessesConcurrentArgumentsOptions =
  {
    execPath :  [ 'node ' + testAppPath + ' 1000', 'node ' + testAppPath + ' 100' ],
    args : [ 'second', 'argument' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
  }

  _.process.start( suprocessesConcurrentArgumentsOptions )
  .then( ( arg ) =>
  {
    var spent = _.time.now() - time;
    logger.log( 'Spent', spent )
    test.gt( spent, 1000 );
    test.le( spent, 5000 );

    test.identical( suprocessesConcurrentArgumentsOptions.exitCode, 0 );
    test.identical( suprocessesConcurrentArgumentsOptions.exitSignal, null );
    test.identical( suprocessesConcurrentArgumentsOptions.exitReason, 'normal' );
    test.identical( suprocessesConcurrentArgumentsOptions.ended, true );
    test.identical( suprocessesConcurrentArgumentsOptions.state, 'terminated' );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 0 );
    test.identical( arg[ 0 ].exitSignal, null );
    test.identical( arg[ 0 ].exitReason, 'normal' );
    test.identical( arg[ 0 ].ended, true );
    test.identical( arg[ 0 ].state, 'terminated' );
    test.is( _.strHas( arg[ 0 ].output, 'begin 1000, second, argument' ) );
    test.is( _.strHas( arg[ 0 ].output, 'end 1000, second, argument' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 100, second, argument' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 100, second, argument' ) );

    counter += 1;
    return null;
  });

  /* - */

  return a.ready.finally( ( err, arg ) =>
  {
    debugger;
    test.identical( counter, 11 );
    if( err )
    throw err;
    return arg;
  });

  function program1()
  {
    var ended = 0;
    var fs = require( 'fs' );
    var path = require( 'path' );
    var filePath = path.join( __dirname, 'file.txt' );
    console.log( 'begin', process.argv.slice( 2 ).join( ', ' ) );
    var time = parseInt( process.argv[ 2 ] );
    if( isNaN( time ) )
    throw new Error( 'Expects number' );

    setTimeout( end, time );
    function end()
    {
      ended = 1;
      fs.writeFileSync( filePath, 'written by ' + process.argv[ 2 ] );
      console.log( 'end', process.argv.slice( 2 ).join( ', ' ) );
    }

    setTimeout( periodic, 50 );
    function periodic()
    {
      console.log( 'tick', process.argv.slice( 2 ).join( ', ' ) );
      if( !ended )
      setTimeout( periodic, 50 );
    }
  }

}

startConcurrent.timeOut = 100000;

//

function shellerConcurrent( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( program1 ) );
  let counter = 0;
  let time = 0;
  let filePath = a.path.nativize( a.abs( a.routinePath, 'file.txt' ) );

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single';
    time = _.time.now();
    return null;
  })

  let singleOption2 = {}
  let singleOption =
  {
    execPath : 'node ' + testAppPath + ' 1000',
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  var shell = _.process.starter( singleOption );
  shell( singleOption2 )

  .then( ( arg ) =>
  {
    test.identical( arg.exitCode, 0 );
    test.identical( arg.exitSignal, null );
    test.identical( arg.exitReason, 'normal' );
    test.identical( arg.ended, true );
    test.identical( arg.state, 'terminated' );
    test.is( singleOption !== arg );
    test.is( singleOption2 === arg );
    test.is( _.strHas( arg.output, 'begin 1000' ) );
    test.is( _.strHas( arg.output, 'end 1000' ) );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single, no second options';
    time = _.time.now();
    return null;
  })

  let singleOptionWithoutSecond =
  {
    execPath : 'node ' + testAppPath + ' 1000',
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  var shell = _.process.starter( singleOptionWithoutSecond );
  shell()

  .then( ( arg ) =>
  {

    test.identical( arg.exitCode, 0 );
    test.identical( arg.exitSignal, null );
    test.identical( arg.exitReason, 'normal' );
    test.identical( arg.ended, true );
    test.identical( arg.state, 'terminated' );
    test.is( singleOptionWithoutSecond !== arg );
    test.is( _.strHas( arg.output, 'begin 1000' ) );
    test.is( _.strHas( arg.output, 'end 1000' ) );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single, execPath in array';
    time = _.time.now();
    return null;
  })

  let singleExecPathInArrayOptions2 = {};
  let singleExecPathInArrayOptions =
  {
    execPath : 'node ' + testAppPath + ' 1000',
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  var shell = _.process.starter( singleExecPathInArrayOptions );
  shell( singleExecPathInArrayOptions2 )

  .then( ( arg ) =>
  {
    test.identical( arg.exitCode, 0 );
    test.identical( arg.exitSignal, null );
    test.identical( arg.exitReason, 'normal' );
    test.identical( arg.ended, true );
    test.identical( arg.state, 'terminated' );
    test.is( singleExecPathInArrayOptions2 === arg );
    test.is( _.strHas( arg.output, 'begin 1000' ) );
    test.is( _.strHas( arg.output, 'end 1000' ) );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single, error in ready, exec is scalar';
    time = _.time.now();
    throw _.err( 'Error!' );
  })

  let singleErrorBeforeScalar2 = {};
  let singleErrorBeforeScalar =
  {
    execPath : 'node ' + testAppPath + ' 1000',
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  var shell = _.process.starter( singleErrorBeforeScalar );
  shell( singleErrorBeforeScalar2 )

  .finally( ( err, arg ) =>
  {

    test.is( arg === undefined );
    test.is( _.errIs( err ) );
    test.identical( singleErrorBeforeScalar.exitCode, undefined );
    test.identical( singleErrorBeforeScalar.output, undefined );
    test.is( !a.fileProvider.fileExists( filePath ) );

    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'single, error in ready, exec is single-element vector';
    time = _.time.now();
    throw _.err( 'Error!' );
  })

  let singleErrorBefore2 = {};
  let singleErrorBefore =
  {
    execPath : [ 'node ' + testAppPath + ' 1000' ],
    ready : a.ready,
    verbosity : 3,
    outputCollecting : 1,
  }

  var shell = _.process.starter( singleErrorBefore );
  shell( singleErrorBefore2 )

  .finally( ( err, arg ) =>
  {

    test.is( arg === undefined );
    test.is( _.errIs( err ) );
    test.identical( singleErrorBefore.exitCode, undefined );
    test.identical( singleErrorBefore.output, undefined );
    test.is( !a.fileProvider.fileExists( filePath ) );

    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, serial';
    time = _.time.now();
    return null;
  })

  let subprocessesOptionsSerial2 = {};
  let subprocessesOptionsSerial =
  {
    execPath :  [ 'node ' + testAppPath + ' 1000', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 0,
  }

  var shell = _.process.starter( subprocessesOptionsSerial );
  shell( subprocessesOptionsSerial2 )

  .then( ( arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 1000 );
    test.le( spent, 5000 );

    test.identical( subprocessesOptionsSerial2.exitCode, 0 );
    test.identical( subprocessesOptionsSerial2.exitSignal, null );
    test.identical( subprocessesOptionsSerial2.exitReason, 'normal' );
    test.identical( subprocessesOptionsSerial2.ended, true );
    test.identical( subprocessesOptionsSerial2.state, 'terminated' );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 0 );
    test.identical( arg[ 0 ].exitSignal, null );
    test.identical( arg[ 0 ].exitReason, 'normal' );
    test.identical( arg[ 0 ].ended, true );
    test.identical( arg[ 0 ].state, 'terminated' );
    test.is( _.strHas( arg[ 0 ].output, 'begin 1000' ) );
    test.is( _.strHas( arg[ 0 ].output, 'end 1000' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 10' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 10' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, serial, error, throwingExitCode : 1';
    time = _.time.now();
    return null;
  })

  let subprocessesError2 = {};
  let subprocessesError =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 0,
  }

  var shell = _.process.starter( subprocessesError );
  shell( subprocessesError2 )

  .finally( ( err, arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesError2.exitCode, 1 );
    test.is( _.errIs( err ) );
    test.is( arg === undefined );
    test.is( !a.fileProvider.fileExists( filePath ) );

    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, serial, error, throwingExitCode : 0';
    time = _.time.now();
    return null;
  })

  let subprocessesErrorNonThrowing2 = {};
  let subprocessesErrorNonThrowing =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 0,
    throwingExitCode : 0,
  }

  var shell = _.process.starter( subprocessesErrorNonThrowing );
  shell( subprocessesErrorNonThrowing2 )

  .then( ( arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesErrorNonThrowing2.exitCode, 1 );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 1 );
    test.is( _.strHas( arg[ 0 ].output, 'begin x' ) );
    test.is( !_.strHas( arg[ 0 ].output, 'end x' ) );
    test.is( _.strHas( arg[ 0 ].output, 'Expects number' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 10' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 10' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, concurrent : 1, error, throwingExitCode : 1';
    time = _.time.now();
    return null;
  })

  let subprocessesErrorConcurrent2 = {};
  let subprocessesErrorConcurrent =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
  }

  var shell = _.process.starter( subprocessesErrorConcurrent );
  shell( subprocessesErrorConcurrent2 )

  .finally( ( err, arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesErrorConcurrent2.exitCode, 1 );
    test.is( _.errIs( err ) );
    test.is( arg === undefined );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    _.errAttend( err );
    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, concurrent : 1, error, throwingExitCode : 0';
    time = _.time.now();
    return null;
  })

  let subprocessesErrorConcurrentNonThrowing2 = {};
  let subprocessesErrorConcurrentNonThrowing =
  {
    execPath :  [ 'node ' + testAppPath + ' x', 'node ' + testAppPath + ' 10' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
    throwingExitCode : 0,
  }

  var shell = _.process.starter( subprocessesErrorConcurrentNonThrowing );
  shell( subprocessesErrorConcurrentNonThrowing2 )

  .then( ( arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent );
    test.gt( spent, 0 );
    test.le( spent, 5000 );

    test.identical( subprocessesErrorConcurrentNonThrowing2.exitCode, 1 );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 10' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 1 );
    test.is( _.strHas( arg[ 0 ].output, 'begin x' ) );
    test.is( !_.strHas( arg[ 0 ].output, 'end x' ) );
    test.is( _.strHas( arg[ 0 ].output, 'Expects number' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 10' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 10' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'subprocesses, concurrent : 1';
    time = _.time.now();
    return null;
  })

  let subprocessesConcurrentOptions2 = {};
  let subprocessesConcurrentOptions =
  {
    execPath :  [ 'node ' + testAppPath + ' 1000', 'node ' + testAppPath + ' 100' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
  }

  var shell = _.process.starter( subprocessesConcurrentOptions );
  shell( subprocessesConcurrentOptions2 )

  .then( ( arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent )
    test.gt( spent, 1000 );
    test.le( spent, 5000 );

    test.identical( subprocessesConcurrentOptions2.exitCode, 0 );
    test.identical( subprocessesConcurrentOptions2.exitSignal, null );
    test.identical( subprocessesConcurrentOptions2.exitReason, 'normal' );
    test.identical( subprocessesConcurrentOptions2.ended, true );
    test.identical( subprocessesConcurrentOptions2.state, 'terminated' );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 0 );
    test.identical( arg[ 0 ].exitSignal, null );
    test.identical( arg[ 0 ].exitReason, 'normal' );
    test.identical( arg[ 0 ].ended, true );
    test.identical( arg[ 0 ].state, 'terminated' );
    test.is( _.strHas( arg[ 0 ].output, 'begin 1000' ) );
    test.is( _.strHas( arg[ 0 ].output, 'end 1000' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 100' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 100' ) );

    counter += 1;
    return null;
  });

  /* - */

  a.ready.then( ( arg ) =>
  {
    test.case = 'args';
    time = _.time.now();
    return null;
  })

  let subprocessesConcurrentArgumentsOptions2 = {}
  let subprocessesConcurrentArgumentsOptions =
  {
    execPath :  [ 'node ' + testAppPath + ' 1000', 'node ' + testAppPath + ' 100' ],
    args : [ 'second', 'argument' ],
    ready : a.ready,
    outputCollecting : 1,
    verbosity : 3,
    concurrent : 1,
  }

  var shell = _.process.starter( subprocessesConcurrentArgumentsOptions );
  shell( subprocessesConcurrentArgumentsOptions2 )

  .then( ( arg ) =>
  {

    var spent = _.time.now() - time;
    logger.log( 'Spent', spent )
    test.gt( spent, 1000 );
    test.le( spent, 5000 );

    test.identical( subprocessesConcurrentArgumentsOptions2.exitCode, 0 );
    test.identical( subprocessesConcurrentArgumentsOptions2.exitSignal, null );
    test.identical( subprocessesConcurrentArgumentsOptions2.exitReason, 'normal' );
    test.identical( subprocessesConcurrentArgumentsOptions2.ended, true );
    test.identical( subprocessesConcurrentArgumentsOptions2.state, 'terminated' );
    test.identical( arg.length, 2 );
    test.identical( a.fileProvider.fileRead( filePath ), 'written by 1000' );
    a.fileProvider.fileDelete( filePath );

    test.identical( arg[ 0 ].exitCode, 0 );
    test.identical( arg[ 0 ].exitSignal, null );
    test.identical( arg[ 0 ].exitReason, 'normal' );
    test.identical( arg[ 0 ].ended, true );
    test.identical( arg[ 0 ].state, 'terminated' );
    test.is( _.strHas( arg[ 0 ].output, 'begin 1000, second, argument' ) );
    test.is( _.strHas( arg[ 0 ].output, 'end 1000, second, argument' ) );

    test.identical( arg[ 1 ].exitCode, 0 );
    test.identical( arg[ 1 ].exitSignal, null );
    test.identical( arg[ 1 ].exitReason, 'normal' );
    test.identical( arg[ 1 ].ended, true );
    test.identical( arg[ 1 ].state, 'terminated' );
    test.is( _.strHas( arg[ 1 ].output, 'begin 100, second, argument' ) );
    test.is( _.strHas( arg[ 1 ].output, 'end 100, second, argument' ) );

    counter += 1;
    return null;
  });

  /* - */

  return a.ready.finally( ( err, arg ) =>
  {
    debugger;
    test.identical( counter, 12 );
    if( err )
    throw err;
    return arg;
  });

  /* - */

  function program1()
  {
    var ended = 0;
    var fs = require( 'fs' );
    var path = require( 'path' );
    var filePath = path.join( __dirname, 'file.txt' );
    console.log( 'begin', process.argv.slice( 2 ).join( ', ' ) );
    var time = parseInt( process.argv[ 2 ] );
    if( isNaN( time ) )
    throw new Error( 'Expects number' );

    setTimeout( end, time );
    function end()
    {
      ended = 1;
      fs.writeFileSync( filePath, 'written by ' + process.argv[ 2 ] );
      console.log( 'end', process.argv.slice( 2 ).join( ', ' ) );
    }

    setTimeout( periodic, 50 );
    function periodic()
    {
      console.log( 'tick', process.argv.slice( 2 ).join( ', ' ) );
      if( !ended )
      setTimeout( periodic, 50 );
    }
  }
}

shellerConcurrent.timeOut = 100000;

// --
// helper
// --

function startNjs( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  var testAppPath = a.program( testApp );
  var testAppPath2 = a.program( testApp2 );

  /* */

  a.ready.then( () =>
  {
    test.case = 'execPath contains normalized path'
    return _.process.startNjs
    ({
      execPath : testAppPath2,
      args : [ 'arg' ],
      outputCollecting : 1,
      stdio : 'pipe',
    })
    .then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( op.args, [ 'arg' ] );
      console.log( op.output )
      test.is( _.strHas( op.output, `[ 'arg' ]` ) );
      return null
    })
  })

  /* */

  // let modes = [ 'fork', 'exec', 'spawn', 'shell' ];
  let modes = [ 'fork', 'spawn', 'shell' ];

  modes.forEach( ( mode ) =>
  {
    a.ready.then( () =>
    {
      var o = { execPath : testAppPath, mode, applyingExitCode : 1, throwingExitCode : 1, stdio : 'ignore', outputPiping : 0, outputCollecting : 0 };
      var con = _.process.startNjs( o );
      return test.shouldThrowErrorAsync( con )
      .finally( () =>
      {
        test.identical( o.exitCode, 1 );
        test.identical( process.exitCode, 1 );
        process.exitCode = 0;
        return true;
      })
    })

    /* */

    a.ready.then( () =>
    {
      var o = { execPath : testAppPath, mode,  applyingExitCode : 1, throwingExitCode : 0, stdio : 'ignore', outputPiping : 0, outputCollecting : 0 };
      return _.process.startNjs( o )
      .finally( ( err, op ) =>
      {
        test.identical( o.exitCode, 1 );
        test.identical( process.exitCode, 1 );
        process.exitCode = 0;
        test.is( !_.errIs( err ) );
        return true;
      })
    })

    /* */

    a.ready.then( () =>
    {
      var o = { execPath : testAppPath,  mode, applyingExitCode : 0, throwingExitCode : 1, stdio : 'ignore', outputPiping : 0, outputCollecting : 0 };
      var con = _.process.startNjs( o )
      return test.shouldThrowErrorAsync( con )
      .finally( () =>
      {
        test.identical( o.exitCode, 1 );
        test.identical( process.exitCode, 0 );
        return true;
      })
    })

    /* */

    a.ready.then( () =>
    {
      var o = { execPath : testAppPath,  mode, applyingExitCode : 0, throwingExitCode : 0, stdio : 'ignore', outputPiping : 0, outputCollecting : 0 };
      return _.process.startNjs( o )
      .finally( ( err, op ) =>
      {
        test.identical( o.exitCode, 1 );
        test.identical( process.exitCode, 0 );
        test.is( !_.errIs( err ) );
        return true;
      })
    })

    /* */

    a.ready.then( () =>
    {
      var o = { execPath : testAppPath,  mode, maximumMemory : 1, applyingExitCode : 0, throwingExitCode : 0, stdio : 'ignore', outputPiping : 0, outputCollecting : 0 };
      return _.process.startNjs( o )
      .finally( ( err, op ) =>
      {
        test.identical( o.exitCode, 1 );
        test.identical( process.exitCode, 0 );
        let spawnArgs = _.toStr( o.process.spawnargs, { levels : 99 } );
        test.is( _.strHasAll( spawnArgs, [ '--expose-gc',  '--stack-trace-limit=999', '--max_old_space_size=' ] ) )
        test.is( !_.errIs( err ) );
        return true;
      })
    })
  })

  return a.ready;

  /* - */

  function testApp()
  {
    throw new Error( 'Error message from child' );
  }

  function testApp2()
  {
    console.log( process.argv.slice( 2 ) )
  }

}

startNjs.timeOut = 20000;

//

/* xxx : add test case for multiple */
/* qqq for Yevhen : subroutine for modes */
function startNjsWithReadyDelayStructural( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( program1 );

  /* */

  a.ready.then( () =>
  {
    test.case = 'basic';
    let con = new _.Consequence().take( null );

    con.timeOut( context.t1 ); /* 1000 */

    let options =
    {
      execPath : programPath,
      currentPath : a.currentPath,
      throwingExitCode : 1,
      inputMirroring : 1,
      outputCollecting : 1,
      stdio : 'pipe',
      sync : 0,
      deasync : 0,
      ready : con,
    }

    let returned = _.process.startNjs( options );

    returned.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( op.output, 'program1:begin\n' );

      let exp2 = _.mapExtend( null, exp );
      exp2.output = 'program1:begin\n';
      exp2.exitCode = 0;
      exp2.exitSignal = null;
      exp2.disconnect = options.disconnect;
      exp2.process = options.process;
      exp2.procedure = options.procedure;
      exp2.stack = options.stack;
      exp2.currentPath = _.path.current();
      exp2.args = [];
      exp2.interpreterArgs = [];
      exp2.outputPiping = true;
      exp2.outputAdditive = true;
      exp2.state = 'terminated';
      exp2.exitReason = 'normal';
      exp2.fullExecPath = a.path.nativize( programPath );
      exp2.ended = true;

      test.identical( options, exp2 );
      test.identical( !!options.process, true );
      test.is( _.routineIs( options.disconnect ) );
      test.is( options.conTerminate !== options.ready );
      test.identical( options.ready.exportString(), 'Consequence:: 0 / 1' );
      test.identical( options.conTerminate.exportString(), 'Consequence:: 1 / 0' );
      test.identical( options.conDisconnect.exportString(), 'Consequence:: 0 / 0' );
      test.identical( options.conStart.exportString(), 'Consequence:: 1 / 0' );

      return null;
    });

    var exp =
    {
      'execPath' : a.path.nativize( a.abs( 'program1.js' ) ),
      'currentPath' : null,
      'throwingExitCode' : 1,
      'inputMirroring' : 1,
      'outputCollecting' : 1,
      'sync' : 0,
      'deasync' : 0,
      'passingThrough' : 0,
      'maximumMemory' : 0,
      'applyingExitCode' : 1,
      'stdio' : [ 'pipe', 'pipe', 'pipe', 'ipc' ],
      'mode' : 'fork',
      'args' : null,
      'interpreterArgs' : '',
      'when' : 'instant',
      'dry' : 0,
      'ipc' : 1,
      'env' : null,
      'detaching' : 0,
      'windowHiding' : 1,
      'concurrent' : 0,
      'timeOut' : null,
      'returningOptionsArray' : 1,
      'briefExitCode' : 0,
      'verbosity' : 2,
      'outputPrefixing' : 0,
      'outputPiping' : null,
      'outputAdditive' : null,
      'outputDecorating' : 0,
      'outputDecoratingStdout' : 0,
      'outputDecoratingStderr' : 0,
      'outputGraying' : 0,
      'conStart' : options.conStart,
      'conTerminate' : options.conTerminate,
      'conDisconnect' : options.conDisconnect,
      'ready' : options.ready,
      'disconnect' : options.disconnect,
      'process' : options.process,
      'logger' : options.logger,
      'stack' : options.stack,
      'state' : 'initial',
      'exitReason' : null,
      'fullExecPath' : null,
      'output' : null,
      'exitCode' : null,
      'exitSignal' : null,
      'procedure' : null,
      'ended' : false,
      'handleProcedureTerminationBegin' : false,
      'error' : null
    }
    test.identical( options, exp );

    test.is( _.routineIs( options.disconnect ) );
    test.is( options.conTerminate !== options.ready );
    test.is( !!options.disconnect );
    test.identical( options.process, null );
    test.is( !!options.logger );
    test.is( !!options.stack );
    test.identical( options.ready.exportString(), 'Consequence:: 0 / 2' );
    test.identical( options.conDisconnect.exportString(), 'Consequence:: 0 / 0' );
    test.identical( options.conTerminate.exportString(), 'Consequence:: 0 / 0' );
    test.identical( options.conStart.exportString(), 'Consequence:: 0 / 0' );

    return returned;
  })

  /* */

  a.ready.then( () =>
  {
    test.case = 'detaching : 1';
    let con = new _.Consequence().take( null );

    con.timeOut( context.t1 ); /* 1000 */

    let options =
    {
      execPath : programPath,
      currentPath : a.currentPath,
      throwingExitCode : 1,
      inputMirroring : 1,
      outputCollecting : 1,
      stdio : 'pipe',
      sync : 0,
      deasync : 0,
      detaching : 1,
      ready : con,
    }

    let returned = _.process.startNjs( options );

    returned.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( op.output, 'program1:begin\n' );

      let exp2 = _.mapExtend( null, exp );
      exp2.output = 'program1:begin\n';
      exp2.exitCode = 0;
      exp2.exitSignal = null;
      exp2.disconnect = options.disconnect;
      exp2.process = options.process;
      exp2.procedure = options.procedure;
      exp2.stack = options.stack;
      exp2.currentPath = _.path.current();
      exp2.args = [];
      exp2.interpreterArgs = [];
      exp2.outputPiping = true;
      exp2.outputAdditive = true;
      exp2.state = 'terminated';
      exp2.exitReason = 'normal';
      exp2.fullExecPath = a.path.nativize( programPath );
      exp2.ended = true;

      test.identical( options, exp2 );
      test.identical( !!options.process, true );
      test.is( _.routineIs( options.disconnect ) );
      test.is( options.conTerminate !== options.ready );
      test.identical( options.ready.exportString(), 'Consequence:: 0 / 1' );
      test.identical( options.conTerminate.exportString(), 'Consequence:: 1 / 0' );
      test.identical( options.conDisconnect.exportString(), 'Consequence:: 0 / 0' );
      test.identical( options.conStart.exportString(), 'Consequence:: 1 / 0' );

      return null;
    });

    var exp =
    {
      'execPath' : a.path.nativize( a.abs( 'program1.js' ) ),
      'currentPath' : null,
      'throwingExitCode' : 1,
      'inputMirroring' : 1,
      'outputCollecting' : 1,
      'sync' : 0,
      'deasync' : 0,
      'passingThrough' : 0,
      'maximumMemory' : 0,
      'applyingExitCode' : 1,
      'stdio' : [ 'pipe', 'pipe', 'pipe', 'ipc' ],
      'mode' : 'fork',
      'args' : null,
      'interpreterArgs' : '',
      'when' : 'instant',
      'dry' : 0,
      'ipc' : 1,
      'env' : null,
      'detaching' : 1,
      'windowHiding' : 1,
      'concurrent' : 0,
      'timeOut' : null,
      'returningOptionsArray' : 1,
      'briefExitCode' : 0,
      'verbosity' : 2,
      'outputPrefixing' : 0,
      'outputPiping' : null,
      'outputAdditive' : null,
      'outputDecorating' : 0,
      'outputDecoratingStdout' : 0,
      'outputDecoratingStderr' : 0,
      'outputGraying' : 0,
      'conStart' : options.conStart,
      'conTerminate' : options.conTerminate,
      'conDisconnect' : options.conDisconnect,
      'ready' : options.ready,
      'disconnect' : options.disconnect,
      'process' : options.process,
      'logger' : options.logger,
      'stack' : options.stack,
      'state' : 'initial',
      'exitReason' : null,
      'fullExecPath' : null,
      'output' : null,
      'exitCode' : null,
      'exitSignal' : null,
      'procedure' : null,
      'ended' : false,
      'handleProcedureTerminationBegin' : false,
      'error' : null
    }
    test.identical( options, exp );

    test.is( _.routineIs( options.disconnect ) );
    test.is( options.conTerminate !== options.ready );
    test.is( !!options.disconnect );
    test.identical( options.process, null );
    test.is( !!options.logger );
    test.is( !!options.stack );
    test.identical( options.ready.exportString(), 'Consequence:: 0 / 2' );
    test.identical( options.conDisconnect.exportString(), 'Consequence:: 0 / 0' );
    test.identical( options.conTerminate.exportString(), 'Consequence:: 0 / 0' );
    test.identical( options.conStart.exportString(), 'Consequence:: 0 / 0' );

    return returned;
  })

  return a.ready;

  /* */

  function program1()
  {
    let _ = require( toolsPath );
    console.log( 'program1:begin' );
  }

}

startNjsWithReadyDelayStructural.description =
`
 - ready has delay
 - value of o-context is correct before start
 - value of o-context is correct after start
`

// --
// sheller
// --

function sheller( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );

  /* */

  a.ready

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath :  'node ' + testAppPath,
      outputCollecting : 1,
      outputPiping : 1
    })

    debugger;
    return shell({ execPath :  [ 'arg1', 'arg2' ] })
    .then( ( op ) =>
    {
      debugger;
      test.identical( op.length, 2 );

      let o1 = op[ 0 ];
      let o2 = op[ 1 ];

      test.identical( o1.execPath, 'node' );
      test.identical( o2.execPath, 'node' );
      test.is( _.strHas( o1.output, `[ 'arg1' ]` ) );
      test.is( _.strHas( o2.output, `[ 'arg2' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath :  'node ' + testAppPath + ' arg0',
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath :  [ 'arg1', 'arg2' ] })
    .then( ( op ) =>
    {
      test.identical( op.length, 2 );

      let o1 = op[ 0 ];
      let o2 = op[ 1 ];

      test.identical( o1.execPath, 'node' );
      test.identical( o2.execPath, 'node' );
      test.is( _.strHas( o1.output, `[ 'arg0', 'arg1' ]` ) );
      test.is( _.strHas( o2.output, `[ 'arg0', 'arg2' ]` ) );

      return op;
    })
  })


  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath :  'node ' + testAppPath,
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath :  [ 'arg1', 'arg2' ], args : [ 'arg3' ] })
    .then( ( op ) =>
    {
      test.identical( op.length, 2 );

      let o1 = op[ 0 ];
      let o2 = op[ 1 ];

      test.identical( o1.execPath, 'node' );
      test.identical( o2.execPath, 'node' );
      test.identical( o1.args, [ testAppPath, 'arg1', 'arg3' ] );
      test.identical( o2.args, [ testAppPath, 'arg2', 'arg3' ] );
      test.is( _.strHas( o1.output, `[ 'arg1', 'arg3' ]` ) );
      test.is( _.strHas( o2.output, `[ 'arg2', 'arg3' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath :  'node ' + testAppPath,
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath :  'arg1' })
    .then( ( op ) =>
    {
      test.identical( op.execPath, 'node' );
      test.is( _.strHas( op.output, `[ 'arg1' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath :
      [
        'node ' + testAppPath,
        'node ' + testAppPath
      ],
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath :  'arg1' })
    .then( ( op ) =>
    {
      test.identical( op.length, 2 );

      let o1 = op[ 0 ];
      let o2 = op[ 1 ];

      test.identical( o1.execPath, 'node' );
      test.identical( o2.execPath, 'node' );
      test.is( _.strHas( o1.output, `[ 'arg1' ]` ) );
      test.is( _.strHas( o2.output, `[ 'arg1' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath :
      [
        'node ' + testAppPath,
        'node ' + testAppPath
      ],
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath :  [ 'arg1', 'arg2' ] })
    .then( ( op ) =>
    {
      test.identical( op.length, 4 );

      let o1 = op[ 0 ];
      let o2 = op[ 1 ];
      let o3 = op[ 2 ];
      let o4 = op[ 3 ];

      test.identical( o1.execPath, 'node' );
      test.identical( o2.execPath, 'node' );
      test.identical( o3.execPath, 'node' );
      test.identical( o4.execPath, 'node' );
      test.is( _.strHas( o1.output, `[ 'arg1' ]` ) );
      test.is( _.strHas( o2.output, `[ 'arg1' ]` ) );
      test.is( _.strHas( o3.output, `[ 'arg2' ]` ) );
      test.is( _.strHas( o4.output, `[ 'arg2' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath : 'node',
      args : 'arg1',
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath : testAppPath })
    .then( ( op ) =>
    {
      test.identical( op.execPath, 'node' );
      test.is( _.strHas( op.output, `[ 'arg1' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath : 'node',
      args : 'arg1',
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath : testAppPath, args : 'arg2' })
    .then( ( op ) =>
    {
      test.identical( op.execPath, 'node' );
      test.is( _.strHas( op.output, `[ 'arg2' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath : 'node',
      args : [ 'arg1', 'arg2' ],
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath : testAppPath, args : 'arg3' })
    .then( ( op ) =>
    {
      test.identical( op.execPath, 'node' );
      test.is( _.strHas( op.output, `[ 'arg3' ]` ) );

      return op;
    })
  })

  .then( () =>
  {
    var shell = _.process.starter
    ({
      execPath : 'node',
      args : 'arg1',
      outputCollecting : 1,
      outputPiping : 1
    })

    return shell({ execPath : testAppPath, args : [ 'arg2', 'arg3' ] })
    .then( ( op ) =>
    {
      test.identical( op.execPath, 'node' );
      test.is( _.strHas( op.output, `[ 'arg2', 'arg3' ]` ) );

      return op;
    })
  })

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

//

function shellerArgs( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );

  /* */


  let shellerOptions =
  {
    outputCollecting : 1,
    args : [ 'arg1', 'arg2' ],
    mode : 'spawn',
    ready : a.ready
  }

  let shell = _.process.starter( shellerOptions )

  /* */

  shell
  ({
    execPath : 'node ' + testAppPath + ' arg3',
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( op.args, [ testAppPath, 'arg3', 'arg1', 'arg2' ] );
    test.identical( _.strCount( op.output, `[ 'arg3', 'arg1', 'arg2' ]` ), 1 );
    test.identical( shellerOptions.args, [ 'arg1', 'arg2' ] );
    return null;
  })

  shell
  ({
    execPath : 'node ' + testAppPath,
    args : [ 'arg3' ]
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( op.args, [ testAppPath, 'arg3' ] );
    test.identical( _.strCount( op.output, `[ 'arg3' ]` ), 1 );
    test.identical( shellerOptions.args, [ 'arg1', 'arg2' ] );
    return null;
  })

  shell
  ({
    execPath : 'node',
    args : [ testAppPath, 'arg3' ]
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( op.args, [ testAppPath, 'arg3' ] );
    test.identical( _.strCount( op.output, `[ 'arg3' ]` ), 1 );
    test.identical( shellerOptions.args, [ 'arg1', 'arg2' ] );
    return null;
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

//

function shellerFields( test )
{

  test.case = 'defaults';
  var start = _.process.starter();

  test.contains( _.mapKeys( start ), _.mapKeys( _.process.start ) );
  test.identical( _.mapKeys( start.defaults ), _.mapKeys( _.process.start.body.defaults ) );
  test.identical( start.pre, _.process.start.pre );
  test.identical( start.body, _.process.start.body );
  test.identical( _.mapKeys( start.predefined ), _.mapKeys( _.process.start.body.defaults ) );

  test.case = 'execPath';
  var start = _.process.starter( 'node -v' );
  test.contains( _.mapKeys( start ), _.mapKeys( _.process.start ) );
  test.identical( _.mapKeys( start.defaults ), _.mapKeys( _.process.start.body.defaults ) );
  test.identical( start.pre, _.process.start.pre );
  test.identical( start.body, _.process.start.body );
  test.identical( _.mapKeys( start.predefined ), _.mapKeys( _.process.start.body.defaults ) );
  test.identical( start.predefined.execPath, 'node -v' );

  test.case = 'object';
  var ready = new _.Consequence().take( null )
  var start = _.process.starter
  ({
    execPath : 'node -v',
    args : [ 'arg1', 'arg2' ],
    ready
  });
  test.contains( _.mapKeys( start ), _.mapKeys( _.process.start ) );
  test.identical( _.mapKeys( start.defaults ), _.mapKeys( _.process.start.body.defaults ) );
  test.identical( start.pre, _.process.start.pre );
  test.identical( start.body, _.process.start.body );
  test.is( _.arraySetIdentical( _.mapKeys( start.predefined ), _.mapKeys( _.process.start.body.defaults ) ) );
  test.identical( start.predefined.execPath, 'node -v' );
  test.identical( start.predefined.args, [ 'arg1', 'arg2' ] );
  test.identical( start.predefined.ready, ready  );
}

// --
// output
// --

function startOptionOutputCollecting( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( program1 ) );
  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => single( mode ) ) );
  return a.ready;

  /*  */

  function single( sync, deasync, mode )
  {
    let ready = new _.Consequence().take( null )

    if( sync && !deasync && mode === 'fork' )
    return null;

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode} outputPiping:1`;

      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        outputPiping : 1,
        outputCollecting : 1,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( op.output, 'program1:begin\n' );
        return op;
      })

      return returned;
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode} outputPiping:0`;

      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        outputPiping : 0,
        outputCollecting : 1,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( op.output, 'program1:begin\n' );
        return op;
      })

      return returned;
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode} outputPiping:null`;

      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        outputPiping : null,
        outputCollecting : 1,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( op.output, 'program1:begin\n' );
        return op;
      })

      return returned;
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode} outputPiping:implicit`;

      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( op.output, 'program1:begin\n' );
        return op;
      })

      return returned;
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode} outputPiping:0 verbosity:0`;

      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        outputPiping : 0,
        outputCollecting : 1,
        verbosity : 0,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( op.output, 'program1:begin\n' );
        return op;
      })

      return returned;
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode} outputPiping:null verbosity:0`;

      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        outputPiping : null,
        outputCollecting : 1,
        verbosity : 0,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( op.output, 'program1:begin\n' );
        return op;
      })

      return returned;
    })

    /* */

    ready.then( () =>
    {
      test.case = `mode:${mode} outputPiping:implicit verbosity:0`;

      let o =
      {
        execPath : mode !== `fork` ? `node ${programPath}` : `${programPath}`,
        currentPath : a.abs( '.' ),
        outputCollecting : 1,
        verbosity : 0,
      }

      let returned = _.process.start( o );

      o.ready.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( op.output, 'program1:begin\n' );
        return op;
      })

      return returned;
    })

    /* */

    return ready;
  }

  /*  */

  function program1()
  {
    console.log( 'program1:begin' );
  }

}

//

function startOptionOutputGraying( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );

  /* */


  let modes = [ 'fork', 'spawn', 'shell' ];

  _.each( modes, ( mode ) =>
  {
    let execPath = testAppPath;
    if( mode !== 'fork' )
    execPath = 'node ' + execPath;

    _.process.start
    ({
      execPath,
      mode,
      outputGraying : 0,
      outputCollecting : 1,
      ready : a.ready
    })
    .then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      let output = _.strSplitNonPreserving({ src : op.output, delimeter : '\n' });
      test.identical( output.length, 2 );
      test.identical( output[ 0 ], '\u001b[31m\u001b[43mColored message1\u001b[49;0m\u001b[39;0m' );
      test.identical( output[ 1 ], '\u001b[31m\u001b[43mColored message2\u001b[49;0m\u001b[39;0m' );
      return null;
    })

    _.process.start
    ({
      execPath,
      mode,
      outputGraying : 1,
      outputCollecting : 1,
      ready : a.ready
    })
    .then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      let output = _.strSplitNonPreserving({ src : op.output, delimeter : '\n' });
      test.identical( output.length, 2 );
      test.identical( output[ 0 ], 'Colored message1' );
      test.identical( output[ 1 ], 'Colored message2' );
      return null;
    })
  })

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( '\u001b[31m\u001b[43mColored message1\u001b[49;0m\u001b[39;0m' )
    console.log( '\u001b[31m\u001b[43mColored message2\u001b[49;0m\u001b[39;0m' )
  }
}

startOptionOutputGraying.timeOut = 15000;

//

function startOptionLogger( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );
  let modes = [ 'fork', 'spawn', 'shell' ];

  /* */

  test.case = 'custom logger with increased level'

  _.each( modes, ( mode ) =>
  {
    let execPath = testAppPath;
    if( mode !== 'fork' )
    execPath = 'node ' + execPath;

    let loggerOutput = '';

    let logger = new _.Logger({ output : null, onTransformEnd });
    logger.up();

    _.process.start
    ({
      execPath,
      mode,
      outputCollecting : 1,
      outputPiping : 1,
      outputDecorating : 1,
      logger,
      ready : a.ready
    })
    .then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( _.strHas( op.output, '  One tab' ) )
      test.is( _.strHas( loggerOutput, '    One tab' ) )
      return null;
    })

    /*  */

    function onTransformEnd( o )
    {
      loggerOutput += o.outputForPrinter[ 0 ] + '\n';
    }
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( '  One tab' );
  }
}

//

function startOptionLoggerTransofrmation( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );

  /* */

  let modes = [ 'fork', 'spawn', 'shell' ];
  var loggerOutput = '';

  var logger = new _.Logger({ output : null, onTransformEnd });

  modes.forEach( ( mode ) =>
  {
    let path = testAppPath;
    if( mode !== 'fork' )
    path = 'node ' + path;

    console.log( mode )

    a.ready.then( () =>
    {
      loggerOutput = '';
      var o = { execPath : path, mode, outputPiping : 0, outputCollecting : 0, logger };
      return _.process.start( o )
      .then( () =>
      {
        test.identical( o.output, null );
        test.is( !_.strHas( loggerOutput, 'testApp-output') );
        console.log( loggerOutput )
        return true;
      })
    })

    a.ready.then( () =>
    {
      loggerOutput = '';
      var o = { execPath : path, mode, outputPiping : 1, outputCollecting : 0, logger };
      return _.process.start( o )
      .then( () =>
      {
        test.identical( o.output, null );
        test.is( _.strHas( loggerOutput, 'testApp-output') );
        return true;
      })
    })

    a.ready.then( () =>
    {
      loggerOutput = '';
      var o = { execPath : path, mode, outputPiping : 0, outputCollecting : 1, logger };
      return _.process.start( o )
      .then( () =>
      {
        test.identical( o.output, 'testApp-output\n\n' );
        test.is( !_.strHas( loggerOutput, 'testApp-output') );
        return true;
      })
    })

    a.ready.then( () =>
    {
      loggerOutput = '';
      var o = { execPath : path, mode, outputPiping : 1, outputCollecting : 1, logger };
      return _.process.start( o )
      .then( () =>
      {
        test.identical( o.output, 'testApp-output\n\n' );
        test.is( _.strHas( loggerOutput, 'testApp-output') );
        return true;
      })
    })
  })

  return a.ready;

  function onTransformEnd( o )
  {
    loggerOutput += o.outputForPrinter[ 0 ];
  }

  function testApp()
  {
    console.log( 'testApp-output\n' );
  }
}

//

function startOutputOptionsCompatibilityLateCheck( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );
  let testAppPathParent = a.path.nativize( a.program( testAppParent ) );

  if( !Config.debug )
  {
    test.identical( 1, 1 );
    return;
  }

  let modes = [ 'spawn', 'fork', 'shell' ];

  modes.forEach( ( mode ) =>
  {
    a.ready.tap( () => test.open( mode ) );
    a.ready.then( () => run( mode ) );
    a.ready.tap( () => test.close( mode ) );
  })

  return a.ready;

  /* */

  function run( mode )
  {
    let commonOptions =
    {
      execPath : mode === 'fork' ? 'testApp.js' : 'node testApp.js',
      mode,
      currentPath : a.routinePath,
    }

    let ready = _.Consequence().take( null )

    .then( () =>
    {
      let o =
      {
        outputPiping : 0,
        outputCollecting : 0,
        stdio : 'ignore',
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 0,
        stdio : 'ignore',
      }
      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 0,
        outputCollecting : 1,
        stdio : 'ignore',
      }
      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : 'ignore',
      }
      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 0,
        outputCollecting : 0,
        stdio : 'pipe',
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 0,
        stdio : 'pipe',
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 0,
        outputCollecting : 1,
        stdio : 'pipe',
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : 'pipe',
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 0,
        outputCollecting : 0,
        stdio : 'inherit',
      }

      _.mapExtend( o, commonOptions );

      let o2 =
      {
        execPath : 'node testAppParent.js',
        mode : 'spawn',
        ipc : 1,
        currentPath : a.routinePath,
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1
      }

      _.process.start( o2 );

      o2.conStart.thenGive( () => o2.process.send( o ) );

      o2.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        return null;
      })

      return o2.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 0,
        stdio : 'inherit',
      }

      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 0,
        outputCollecting : 1,
        stdio : 'inherit',
      }

      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : 'inherit',
      }

      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'ignore', 'ignore', 'ignore', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'inherit', 'inherit', 'inherit', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      return test.shouldThrowErrorAsync( _.process.start( o ) );
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'pipe', 'pipe', 'pipe', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'ignore', 'pipe', 'ignore', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'ignore', 'ignore', 'pipe', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( !_.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'ignore', 'pipe', 'inherit', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'ignore', 'inherit', 'pipe', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      let o2 =
      {
        execPath : 'node testAppParent.js',
        mode : 'spawn',
        ipc : 1,
        currentPath : a.routinePath,
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1
      }

      _.process.start( o2 );

      o2.conStart.thenGive( () => o2.process.send( o ) );

      o2.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o2.conTerminate;
    })

    /* */

    .then( () =>
    {
      let o =
      {
        outputPiping : 1,
        outputCollecting : 1,
        stdio : [ 'ignore', 'pipe', 'pipe', mode === 'fork' ? 'ipc' : null ],
      }

      _.mapExtend( o, commonOptions );

      _.process.start( o );

      o.conTerminate.then( ( op ) =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'Test output' ) );
        return null;
      })

      return o.conTerminate;
    })

    return ready;
  }

  /* */

  function testApp()
  {
    let _ = require( toolsPath );
    console.log( 'Test output' );
  }

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wFiles' );
    _.include( 'wProcess' );

    let ready = new _.Consequence();

    process.on( 'message', ( op ) =>
    {
      ready.take( op );
      process.disconnect();
    })

    ready.then( ( op ) => _.process.start( op ) );
  }
}

//

function startOptionVerbosity( test )
{
  let context = this;
  let a = context.assetFor( test, false );

  let capturedOutput = '';
  let captureLogger = new _.Logger({ output : null, onTransformEnd, raw : 1 })

  /* */

  testCase( 'verbosity : 0' )
  _.process.start
  ({
    execPath : `node -e "console.log('message')"`,
    mode : 'spawn',
    verbosity : 0,
    outputPiping : null,
    outputCollecting : 0,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( capturedOutput, '' );
    return true;
  })

  /* */

  testCase( 'verbosity : 1' )
  _.process.start
  ({
    execPath : `node -e "console.log('message')"`,
    mode : 'spawn',
    verbosity : 1,
    outputPiping : null,
    outputCollecting : 0,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    console.log( capturedOutput )
    test.identical( _.strCount( capturedOutput, `node -e console.log('message')`), 1 );
    test.identical( _.strCount( capturedOutput, 'message' ), 1 );
    test.identical( _.strCount( capturedOutput, 'at ' + _.path.current() ), 0 );
    return true;
  })

  /* */

  testCase( 'verbosity : 2' )
  _.process.start
  ({
    execPath : `node -e "console.log('message')"`,
    mode : 'spawn',
    verbosity : 2,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( capturedOutput, `node -e console.log('message')` ), 1 );
    test.identical( _.strCount( capturedOutput, 'message' ), 2 );
    test.identical( _.strCount( capturedOutput, 'at ' + _.path.current() ), 0 );
    return true;
  })

  /* */

  testCase( 'verbosity : 3' )
  _.process.start
  ({
    execPath : `node -e "console.log('message')"`,
    mode : 'spawn',
    verbosity : 3,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( capturedOutput, `node -e console.log('message')` ), 1 );
    test.identical( _.strCount( capturedOutput, 'message' ), 2 );
    test.identical( _.strCount( capturedOutput, 'at ' + _.path.current() ), 1 );
    return true;
  })

  /* */

  testCase( 'verbosity : 5' )
  _.process.start
  ({
    execPath : `node -e "console.log('message')"`,
    mode : 'spawn',
    verbosity : 5,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( _.strCount( capturedOutput, `node -e console.log('message')` ), 1 );
    test.identical( _.strCount( capturedOutput, 'message' ), 2 );
    test.identical( _.strCount( capturedOutput, 'at ' + _.path.current() ), 1 );
    return true;
  })

  /* */

  testCase( 'error, verbosity : 0' )
  _.process.start
  ({
    execPath : `node -e "process.exit(1)"`,
    mode : 'spawn',
    verbosity : 0,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    throwingExitCode : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 1 );
    test.identical( op.ended, true );
    test.identical( _.strCount( capturedOutput, 'Process returned error code ' + op.exitCode ), 0 );
    return true;
  })

  /* */

  testCase( 'error, verbosity : 1' )
  _.process.start
  ({
    execPath : `node -e "process.exit(1)"`,
    mode : 'spawn',
    verbosity : 1,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    throwingExitCode : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 1 );
    test.identical( op.ended, true );
    test.identical( _.strCount( capturedOutput, 'Process returned error code ' + op.exitCode ), 0 );
    return true;
  })

  /* */

  testCase( 'error, verbosity : 2' )
  _.process.start
  ({
    execPath : `node -e "process.exit(1)"`,
    mode : 'spawn',
    verbosity : 2,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    throwingExitCode : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 1 );
    test.identical( op.ended, true );
    test.identical( _.strCount( capturedOutput, 'Process returned error code ' + op.exitCode ), 0 );
    return true;
  })

  /* */

  testCase( 'error, verbosity : 3' )
  _.process.start
  ({
    execPath : `node -e "process.exit(1)"`,
    mode : 'spawn',
    verbosity : 3,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    throwingExitCode : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 1 );
    test.identical( op.ended, true );
    test.identical( _.strCount( capturedOutput, 'Process returned error code ' + op.exitCode ), 0 );
    return true;
  })

  /* */

  testCase( 'error, verbosity : 5' )
  _.process.start
  ({
    execPath : `node -e "process.exit(1)"`,
    mode : 'spawn',
    verbosity : 5,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    throwingExitCode : 0,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 1 );
    test.identical( op.ended, true );
    test.identical( _.strCount( capturedOutput, 'Process returned error code ' + op.exitCode ), 1 );
    return true;
  })

  /* */

  testCase( 'execPath has quotes, verbosity : 1' )
  _.process.start
  ({
    execPath : `node -e "console.log( \"a\", 'b', \`c\` )"`,
    mode : 'spawn',
    verbosity : 5,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    throwingExitCode : 1,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( op.fullExecPath, `node -e console.log( \"a\", 'b', \`c\` )` );
    test.identical( _.strCount( capturedOutput, `node -e console.log( \"a\", 'b', \`c\` )` ), 1 );
    return true;
  })

  /* */

  testCase( 'execPath has double quotes, verbosity : 1' )
  _.process.start
  ({
    execPath : `node -e "console.log( '"a"', "'b'", \`"c"\` )"`,
    mode : 'spawn',
    verbosity : 5,
    stdio : 'pipe',
    outputPiping : null,
    outputCollecting : 0,
    throwingExitCode : 1,
    outputDecorating : 1,
    logger : captureLogger,
    ready : a.ready
  })
  .then( ( op ) =>
  {
    test.identical( op.exitCode, 0 );
    test.identical( op.exitSignal, null );
    test.identical( op.exitReason, 'normal' );
    test.identical( op.ended, true );
    test.identical( op.state, 'terminated' );
    test.identical( op.fullExecPath, `node -e console.log( '"a"', "'b'", \`"c"\` )` );
    test.identical( _.strCount( capturedOutput, `node -e console.log( '"a"', "'b'", \`"c"\` )` ), 1 );
    return true;
  })

  return a.ready;

  /*  */

  function testCase( src )
  {
    a.ready.then( () =>
    {
      capturedOutput = '';
      test.case = src;
      return null
    });
  }

  function onTransformEnd( o )
  {
    capturedOutput += o.outputForPrinter[ 0 ] + '\n';
  }
}

// --
// etc
// --

function appTempApplication( test )
{
  let context = this;

  /* */

  function testApp()
  {
    console.log( process.argv.slice( 2 ) );
  }

  let testAppCode = testApp.toString() + '\ntestApp();';

  /* */

  test.case = 'string';
  var returned = _.process.tempOpen( testAppCode );
  var read = _.fileProvider.fileRead( returned );
  test.identical( read, testAppCode );
  _.process.tempClose( returned );
  test.is( !_.fileProvider.fileExists( returned ) );

  /* */

  test.case = 'string';
  var returned = _.process.tempOpen({ sourceCode : testAppCode });
  var read = _.fileProvider.fileRead( returned );
  test.identical( read, testAppCode );
  _.process.tempClose( returned );
  test.is( !_.fileProvider.fileExists( returned ) );

  /* */

  test.case = 'raw buffer';
  var returned = _.process.tempOpen( _.bufferRawFrom( testAppCode ) );
  var read = _.fileProvider.fileRead( returned );
  test.identical( read, testAppCode );
  _.process.tempClose( returned );
  test.is( !_.fileProvider.fileExists( returned ) );

  /* */

  test.case = 'raw buffer';
  var returned = _.process.tempOpen({ sourceCode : _.bufferRawFrom( testAppCode ) });
  var read = _.fileProvider.fileRead( returned );
  test.identical( read, testAppCode );
  _.process.tempClose( returned );
  test.is( !_.fileProvider.fileExists( returned ) );

  /* */

  test.case = 'remove all';
  var returned1 = _.process.tempOpen( testAppCode );
  var returned2 = _.process.tempOpen( testAppCode );
  test.is( _.fileProvider.fileExists( returned1 ) );
  test.is( _.fileProvider.fileExists( returned2 ) );
  _.process.tempClose();
  test.is( !_.fileProvider.fileExists( returned1 ) );
  test.is( !_.fileProvider.fileExists( returned2 ) );
  test.mustNotThrowError( () => _.process.tempClose() )

  if( !Config.debug )
  return;

  test.case = 'unexpected type of sourceCode option';
  test.shouldThrowErrorSync( () =>
  {
    _.process.tempOpen( [] );
  })

  /* */

  test.case = 'unexpected option';
  test.shouldThrowErrorSync( () =>
  {
    _.process.tempOpen({ someOption : true });
  })

  /* */

  test.case = 'try to remove file that does not exist in registry';
  var returned = _.process.tempOpen( testAppCode );
  _.process.tempClose( returned );
  test.shouldThrowErrorSync( () =>
  {
    _.process.tempClose( returned );
  })
}

//

function startDiffPid( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testFilePath = a.abs( a.routinePath, 'testFile' );
  let modes = [ 'fork', 'spawn', 'shell' ];

  modes.forEach( ( mode ) =>
  {
    a.ready.then( () =>
    {
      a.fileProvider.filesDelete( a.routinePath );
      let locals =
      {
        toolsPath : _.path.nativize( _.module.toolsPathGet() ),
        mode,
      }
      a.path.nativize( a.program({ routine : testAppParent, locals }) );
      a.path.nativize( a.program( testAppChild ) );
      return null;
    })

    a.ready.tap( () => test.open( mode ) );
    a.ready.then( () => run( mode ) );
    a.ready.tap( () => test.close( mode ) );
  });

  return a.ready;

  /* - */

  function run( mode )
  {
    let ready = new _.Consequence().take( null )

    /*  */

    ready.then( () =>
    {
      test.case = 'process termination begins after short delay, detached process should continue to work after parent death';

      a.fileProvider.filesDelete( testFilePath );
      a.fileProvider.dirMakeForFile( testFilePath );

      let o =
      {
        execPath : 'node testAppParent.js stdio : ignore outputPiping : 0 outputCollecting : 0',
        mode : 'spawn',
        outputCollecting : 1,
        currentPath : a.routinePath,
        ipc : 1,
      }
      let con = _.process.start( o );
      let data;

      o.process.on( 'message', ( e ) =>
      {
        data = e;
        data.childPid = _.numberFrom( data.childPid );
      })

      con.then( ( op ) =>
      {
        test.will = 'parent is dead, child is still alive';
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( !_.process.isAlive( op.process.pid ) );
        test.is( _.process.isAlive( data.childPid ) );
        return _.time.out( context.t2 * 2 );
      })

      con.then( () =>
      {
        test.will = 'both dead';

        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( data.childPid ) );

        test.is( a.fileProvider.fileExists( testFilePath ) );
        let childPid = a.fileProvider.fileRead( testFilePath );
        childPid = _.numberFrom( childPid );
        console.log(  childPid );
        if( mode !== 'shell' )
        test.identical( data.childPid, childPid );
        console.log( `${mode} : PID is ${ data.childPid === childPid ? 'same' : 'different' }` );

        return null;
      })

      return con;
    })

    /*  */

    return ready;
  }

  /*  */

  function testAppParent()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    let args = _.process.args();

    let o =
    {
      execPath : mode === 'fork' ? 'testAppChild.js' : 'node testAppChild.js',
      mode,
      detaching : true,
    }

    _.mapExtend( o, args.map );

    _.process.start( o );

    console.log( o.process.pid )

    process.send({ childPid : o.process.pid });

    o.conStart.thenGive( () =>
    {
      _.procedure.terminationBegin();
    })
  }

  function testAppChild()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    console.log( 'Child process start', process.pid );
    _.time.out( 2000, () =>
    {
      let filePath = _.path.join( __dirname, 'testFile' );
      _.fileProvider.fileWrite( filePath, _.toStr( process.pid ) );
      console.log( 'Child process end' )
      return null;
    })
  }
}

startDiffPid.timeOut = 180000;

// --
// other options
// --

function startOptionDryRun( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( testApp );

  /*  */

  a.ready.then( () =>
  {
    test.case = 'trivial'
    let o =
    {
      execPath : 'node ' + programPath + ` arg1 "arg 2" "'arg3'"`,
      mode : 'spawn',
      args : [ 'arg0' ],
      sync : 0,
      dry : 1,
      deasync : 0,
      outputPiping : 1,
      outputCollecting : 1,
      throwingExitCode : 1,
      applyingExitCode : 1,
      timeOut : 100,
      ipc : 1,
      when : { delay : 1000 }
    }
    var t1 = _.time.now();
    var returned = _.process.start( o );
    test.is( _.consequenceIs( returned ) );
    returned.then( function( op )
    {
      var t2 = _.time.now();
      test.ge( t2 - t1, 1000 )

      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, null );
      test.identical( op.process, null );
      test.identical( op.stdio, [ 'pipe', 'pipe', 'pipe', 'ipc' ] );
      test.identical( op.fullExecPath, `node ${programPath} arg1 arg 2 'arg3' arg0` );
      test.identical( op.output, '' );

      test.is( !a.fileProvider.fileExists( a.path.join( a.routinePath, 'file' ) ) )

      return op;
    })
    return returned;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    var fs = require( 'fs' );
    var path = require( 'path' );
    var filePath = path.join( __dirname, 'file' );
    fs.writeFileSync( filePath, filePath );
  }
}

startOptionDryRun.description =
`
Simulates run of routine start with all possible options.
After execution checks fields of run descriptor.
`

//

/* qqq for Yevhen : split by modes | aaa : Done. Yevhen S.
qqq for Yevhen : not really
*/

function startOptionCurrentPath( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testFilePath = a.path.join( a.routinePath, 'program1TestFile' );
  // let locals = { toolsPath : context.toolsPath, testFilePath };
  let locals = { testFilePath };
  let programPath = a.program({ routine : program1, locals });
  // let programPath = a.path.nativize( a.program({ routine : program1, locals }) );
  let modes = [ 'shell', 'spawn', 'fork' ]

  modes.forEach( ( mode ) =>
  {
    a.ready.tap( () => test.open( mode ) )
    a.ready.then( () => run( mode ) )
    a.ready.tap( () => test.close( mode ) )
  })

  return a.ready;

  /* */

  function run( mode )
  {
    let ready = new _.Consequence().take( null );

    ready.then( function()
    {
      let o =
      {
        execPath :  mode !== 'fork' ? 'node ' + programPath : programPath,
        currentPath : __dirname,
        mode,
        stdio : 'pipe',
        outputCollecting : 1,
      }
      return _.process.start( o )
      .then( function( op )
      {
        let got = a.fileProvider.fileRead( testFilePath );
        test.identical( got, __dirname );
        return null;
      })
    })

    /* */

    ready.then( function()
    {
      test.case = 'normalized, currentPath leads to root of current drive';

      let trace = a.path.traceToRoot( a.path.normalize( __dirname ) );
      let currentPath = trace[ 1 ];

      let o =
      {
        execPath :  mode !== 'fork' ? 'node ' + programPath : programPath,
        currentPath,
        mode,
        stdio : 'pipe',
        outputCollecting : 1,
      }

      return _.process.start( o )
      .then( function( op )
      {
        let got = a.fileProvider.fileRead( testFilePath );
        test.identical( got, a.path.nativize( currentPath ) );
        return null;
      })
    })

    /* */

    ready.then( function()
    {
      test.case = 'normalized with slash, currentPath leads to root of current drive';

      let trace = a.path.traceToRoot( a.path.normalize( __dirname ) );
      let currentPath = trace[ 1 ] + '/';

      let o =
      {
        execPath :  mode !== 'fork' ? 'node ' + programPath : programPath,
        currentPath,
        mode,
        stdio : 'pipe',
        outputCollecting : 1,
      }

      return _.process.start( o )
      .then( function( op )
      {
        let got = a.fileProvider.fileRead( testFilePath );
        if( process.platform === 'win32')
        test.identical( got, a.path.nativize( currentPath ) );
        else
        test.identical( got, trace[ 1 ] );
        return null;
      })
    })

    /* */

    ready.then( function()
    {
      test.case = 'nativized, currentPath leads to root of current drive';

      let trace = a.path.traceToRoot( __dirname );
      let currentPath = a.path.nativize( trace[ 1 ] )

      let o =
      {
        execPath :  mode !== 'fork' ? 'node ' + programPath : programPath,
        currentPath,
        mode,
        stdio : 'pipe',
        outputCollecting : 1,
      }

      return _.process.start( o )
      .then( function( op )
      {
        let got = a.fileProvider.fileRead( testFilePath );
        test.identical( got, currentPath )
        return null;
      })
    })

    return ready;
  }



  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    _.include( 'wFiles' );
    _.fileProvider.fileWrite( testFilePath, process.cwd() );
  }

}

//

/* qqq for Yevhen : try to introduce subroutine for modes */
function startOptionCurrentPaths( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.path.nativize( a.program( testApp ) );

  let o2 =
  {
    execPath : 'node ' + programPath,
    ready : a.ready,
    currentPath : [ a.routinePath, __dirname ],
    stdio : 'pipe',
    outputCollecting : 1
  }

  /* */

  _.process.start( _.mapSupplement( { mode : 'shell' }, o2 ) );

  a.ready.then( ( op ) =>
  {
    let o1 = op[ 0 ];
    let o2 = op[ 1 ];

    test.is( _.strHas( o1.output, a.path.nativize( a.routinePath ) ) );
    test.identical( o1.exitCode, 0 );
    test.identical( o1.exitSignal, null );
    test.identical( o1.exitReason, 'normal' );
    test.identical( o1.ended, true );
    test.identical( o1.state, 'terminated' );

    test.is( _.strHas( o2.output, __dirname ) );
    test.identical( o2.exitCode, 0 );
    test.identical( o2.exitSignal, null );
    test.identical( o2.exitReason, 'normal' );
    test.identical( o2.ended, true );
    test.identical( o2.state, 'terminated' );

    return op;
  })

  /* */

  _.process.start( _.mapSupplement( { mode : 'spawn' }, o2 ) );

  a.ready.then( ( op ) =>
  {
    let o1 = op[ 0 ];
    let o2 = op[ 1 ];

    test.is( _.strHas( o1.output, a.path.nativize( a.routinePath ) ) );
    test.identical( o1.exitCode, 0 );
    test.identical( o1.exitSignal, null );
    test.identical( o1.exitReason, 'normal' );
    test.identical( o1.ended, true );
    test.identical( o1.state, 'terminated' );

    test.is( _.strHas( o2.output, __dirname ) );
    test.identical( o2.exitCode, 0 );
    test.identical( o2.exitSignal, null );
    test.identical( o2.exitReason, 'normal' );
    test.identical( o2.ended, true );
    test.identical( o2.state, 'terminated' );

    return op;
  })

  /* */

  _.process.start( _.mapSupplement( { mode : 'fork', execPath : programPath }, o2 ) );

  a.ready.then( ( op ) =>
  {
    let o1 = op[ 0 ];
    let o2 = op[ 1 ];

    test.is( _.strHas( o1.output, a.path.nativize( a.routinePath ) ) );
    test.identical( o1.exitCode, 0 );
    test.identical( o1.exitSignal, null );
    test.identical( o1.exitReason, 'normal' );
    test.identical( o1.ended, true );
    test.identical( o1.state, 'terminated' );

    test.is( _.strHas( o2.output, __dirname ) );
    test.identical( o2.exitCode, 0 );
    test.identical( o2.exitSignal, null );
    test.identical( o2.exitReason, 'normal' );
    test.identical( o2.ended, true );
    test.identical( o2.state, 'terminated' );

    return op;
  })

  /*  */

  _.process.start( _.mapSupplement( { mode : 'spawn', execPath : [ 'node ' + programPath, 'node ' + programPath ] }, o2 ) );

  a.ready.then( ( op ) =>
  {
    let o1 = op[ 0 ];
    let o2 = op[ 1 ];
    let o3 = op[ 2 ];
    let o4 = op[ 3 ];

    test.is( _.strHas( o1.output, a.path.nativize( a.routinePath ) ) );
    test.identical( o1.exitCode, 0 );
    test.identical( o1.exitSignal, null );
    test.identical( o1.exitReason, 'normal' );
    test.identical( o1.ended, true );
    test.identical( o1.state, 'terminated' );

    test.is( _.strHas( o2.output, __dirname ) );
    test.identical( o2.exitCode, 0 );
    test.identical( o2.exitSignal, null );
    test.identical( o2.exitReason, 'normal' );
    test.identical( o2.ended, true );
    test.identical( o2.state, 'terminated' );

    test.is( _.strHas( o3.output, a.path.nativize( a.routinePath ) ) );
    test.identical( o3.exitCode, 0 );
    test.identical( o3.exitSignal, null );
    test.identical( o3.exitReason, 'normal' );
    test.identical( o3.ended, true );
    test.identical( o3.state, 'terminated' );

    test.is( _.strHas( o4.output, __dirname ) );
    test.identical( o4.exitCode, 0 );
    test.identical( o4.exitSignal, null );
    test.identical( o4.exitReason, 'normal' );
    test.identical( o4.ended, true );
    test.identical( o4.state, 'terminated' );

    return op;
  })

  return a.ready;

  /* - */

  function testApp()
  {
    console.log( process.cwd() );
  }
}

//

function startOptionPassingThrough( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath1 = a.path.nativize( a.program( program1 ) );
  let testAppPath2 = a.path.nativize( a.program( program2 ) );

  /*
   program1 spawns program2 with options read from op.js
   Options for program2 are provided to program1 through file op.js.
   This method is used instead of ipc messages because second method requires to call process.disconnect in program1,
   otherwise program1 will not exit after termination of program2.
   File op.js is written on each test case, before spawn of program1
   Also, this method is used to exclude output of program2 from tester in case when stdio:inherit is used
  */

  run();

  return a.ready;

  function run()
  {
    a.ready.then( () =>
    {
      test.open( '0 args to parent process' );
      return null;
    } );

    a.ready.then( () =>
    {
      test.case = 'child args = `testAppPath2`';
      let o =
      {
        args : testAppPath2,
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[]\n` );
        return null;
      })

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child : none';

      let o =
      {
        execPath : testAppPath2,
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child : a';

      let o =
      {
        execPath : testAppPath2,
        args : 'a',
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ \'a\' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /*  */

    a.ready.then( () =>
    {
      test.case = 'args to child : a, b, c';

      let o =
      {
        execPath : testAppPath2,
        args : [ 'a', 'b', 'c' ],
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ \'a\', \'b\', \'c\' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child in execPath: a, b, c';

      let o =
      {
        execPath : testAppPath2 + ' a b c',
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ \'a\', \'b\', \'c\' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child in execPath: a and in args : b, c';

      let o =
      {
        execPath : testAppPath2 + ' a',
        args : [ 'b', 'c' ],
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ \'a\', \'b\', \'c\' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      /* mode : shell, stdio : pipe, passingThrough : true */

      test.case = 'mode : shell, passingThrough : true, parent args : none, child args : none';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent1, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[]\n' )

        return null;
      })

      /* - */

      function testAppParent1()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node ' + programPath,
          mode : 'shell',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0,
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    /* */

    a.ready.then( function()
    {
      /* mode : spawn, stdio : pipe, passingThrough : true */
      test.case = 'mode : spawn, passingThrough : true, parent args : none, child args : programPath';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent2, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[]\n' )

        return null;
      })

      /* - */

      function testAppParent2()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node',
          args : [ programPath ],
          mode : 'spawn',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    /* */

    a.ready.then( function()
    {
      /* mode : shell, stdio : pipe, passingThrough : true */

      test.case = 'mode : shell, passingThrough : true, parent args : none, child args : "staging", "debug"';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent3, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[ \'staging\', \'debug\' ]\n' )
        return null;
      })

      /* - */

      function testAppParent3()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node ' + programPath,
          args : [ 'staging', 'debug' ],
          mode : 'shell',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })


    a.ready.then( () =>
    {
      test.close( '0 args to parent process' );
      return null;
    } )

    /* - */

    a.ready.then( () =>
    {
      test.open( '1 arg to parent process' );
      return null;
    } );

    a.ready.then( () =>
    {
      test.case = 'args to child : none; args to parent : parentA';

      let o =
      {
        execPath : testAppPath2,
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        args : 'parentA',
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'parentA' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child : a; args to parent : parentA';

      let o =
      {
        execPath : testAppPath2,
        args : 'a',
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        args : 'parentA',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'parentA' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /*  */

    a.ready.then( () =>
    {
      test.case = 'args to child : a, b, c; args to parent : parentA';

      let o =
      {
        execPath : testAppPath2,
        args : [ 'a', 'b', 'c' ],
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        args : 'parentA',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'b', 'c', 'parentA' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child in execPath: a, b, c; args to parent in execPath : parentA';

      let o =
      {
        execPath : testAppPath2 + ' a b c',
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1 + ' parentA',
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'b', 'c', 'parentA' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child in execPath: a and in args : b, c; args to parent in execPath : parentA, and in args : empty array'

      let o =
      {
        execPath : testAppPath2 + ' a',
        args : [ 'b', 'c' ],
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1 + ' parentA',
        args : [],
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'b', 'c', 'parentA' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    /* ORIGINAL

    let programPath = a.path.nativize( a.program( testApp ) );

    let o3 =
    {
      outputPiping : 1,
      outputCollecting : 1,
      applyingExitCode : 0,
      throwingExitCode : 1
    }

    let o2;

    function testApp()
    {
      console.log( process.argv.slice( 2 ).join( ' ' ) );
    }
    */

    /* ORIGINAL */
    // a.ready.then( function()
    // {
    //   test.case = 'mode : shell, passingThrough : true, no args';

    //   o2 =
    //   {
    //     execPath :  'node ' + programPath,
    //     mode : 'shell',
    //     passingThrough : 1,
    //     stdio : 'pipe'
    //   }

    //   return null;
    // })
    // .then( function( arg )
    // {
    //   /* mode : shell, stdio : pipe, passingThrough : true */

    //   var options = _.mapSupplement( {}, o2, o3 );

    //   return _.process.start( options )
    //   .then( function()
    //   {
    //     test.identical( options.exitCode, 0 );
    //     var expectedArgs= _.arrayAppendArray( [], process.argv.slice( 2 ) );
    //     test.identical( options.output, expectedArgs.join( ' ' ) + '\n' );
    //     return null;
    //   })
    // })


    /* REWRITTEN */
    /* NOT COMPLETED */
    /* PASSES basic checks */
    a.ready.then( () =>
    {
      /* mode : shell, stdio : pipe, passingThrough : true */

      test.case = 'mode : shell, passingThrough : true, parent args : testArg, child args : none';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent4, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
        args : 'testArg',
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[ \'testArg\' ]\n' )

        return null;
      })

      /* - */

      function testAppParent4()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node ' + programPath,
          mode : 'shell',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0,
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    /* */

    /* ORIGINAL */
    // a.ready.then( function()
    // {
    //   test.case = 'mode : spawn, passingThrough : true, only filePath in args';

    //   o2 =
    //   {
    //     execPath :  'node',
    //     args : [ programPath ],
    //     mode : 'spawn',
    //     passingThrough : 1,
    //     stdio : 'pipe'
    //   }
    //   return null;
    // })
    // .then( function( arg )
    // {
    //   /* mode : spawn, stdio : pipe, passingThrough : true */

    //   var options = _.mapSupplement( {}, o2, o3 );

    //   return _.process.start( options )
    //   .then( function()
    //   {
    //     test.identical( options.exitCode, 0 );
    //     var expectedArgs = _.arrayAppendArray( [], process.argv.slice( 2 ) );
    //     test.identical( options.output, expectedArgs.join( ' ' ) + '\n' );
    //     return null;
    //   })
    // })

    /* REWRITTEN */
    /* NOT COMPLETED */
    /* PASSES basic checks */
    a.ready.then( function()
    {
      /* mode : spawn, stdio : pipe, passingThrough : true */
      test.case = 'mode : spawn, passingThrough : true, parent args : testArg, child args : programPath';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent5, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
        args : 'testArg'
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[ \'testArg\' ]\n' )

        return null;
      })

      /* - */

      function testAppParent5()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node',
          args : [ programPath ],
          mode : 'spawn',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    /* */

    /* ORIGINAL */
    // a.ready.then( function()
    // {
    //   test.case = 'mode : shell, passingThrough : true';

    //   o2 =
    //   {
    //     execPath :  'node ' + programPath,
    //     args : [ 'staging', 'debug' ],
    //     mode : 'shell',
    //     passingThrough : 1,
    //     stdio : 'pipe'
    //   }
    //   return null;
    // })
    // .then( function( arg )
    // {
    //   /* mode : shell, stdio : pipe, passingThrough : true */

    //   var options = _.mapSupplement( {}, o2, o3 );

    //   return _.process.start( options )
    //   .then( function()
    //   {
    //     test.identical( options.exitCode, 0 );
    //     var expectedArgs = _.arrayAppendArray( [ 'staging', 'debug' ], process.argv.slice( 2 ) );
    //     test.identical( options.output, expectedArgs.join( ' ' ) + '\n');
    //     return null;
    //   })
    // })

    /* REWRITTEN */
    /* NOT COMPLETED */
    /* PASSES basic checks */
    a.ready.then( function()
    {
      /* mode : shell, stdio : pipe, passingThrough : true */

      test.case = 'mode : shell, passingThrough : true, parent args : testArg, child args : "staging", "debug" ';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent6, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
        args : 'testArg',
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[ \'staging\', \'debug\', \'testArg\' ]\n' )
        return null;
      })

      /* - */

      function testAppParent6()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node ' + programPath,
          args : [ 'staging', 'debug' ],
          mode : 'shell',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    a.ready.then( () =>
    {
      test.close( '1 arg to parent process' );
      return null;
    } )

    /* - */

    a.ready.then( () =>
    {
      test.open( '2 args to parent process' );
      return null;
    } )


    a.ready.then( () =>
    {
      /* mode : shell, stdio : pipe, passingThrough : true */

      test.case = 'mode : shell, passingThrough : true, parent args : testArg1, testArg2, child args : none';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent7, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
        args : [ 'testArg1', 'testArg2' ]
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[ \'testArg1\', \'testArg2\' ]\n' )

        return null;
      })

      /* - */

      function testAppParent7()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node ' + programPath,
          mode : 'shell',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0,
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    /* */

    a.ready.then( function()
    {
      /* mode : spawn, stdio : pipe, passingThrough : true */
      test.case = 'mode : spawn, passingThrough : true, parent args : testArg1, testArg2, child args : programPath';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent8, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
        args : [ 'testArg1', 'testArg2' ]
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[ \'testArg1\', \'testArg2\' ]\n' )

        return null;
      })

      /* - */

      function testAppParent8()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node',
          args : [ programPath ],
          mode : 'spawn',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    a.ready.then( function()
    {
      /* mode : shell, stdio : pipe, passingThrough : true */

      test.case = 'mode : shell, passingThrough : true, parent args : testArg1, testArg2, child args : "staging", "debug"';

      let locals =
      {
        toolsPath : a.path.nativize( _.module.toolsPathGet() ),
        routinePath : a.routinePath,
        programPath : testAppPath2
      }

      let programPath = a.path.nativize( a.program({ routine : testAppParent9, locals }) );

      let options =
      {
        execPath :  'node ' + programPath,
        outputCollecting : 1,
        outputPiping : 0,
        args : [ 'testArg1', 'testArg2' ]
      }

      return _.process.start( options )
      .then( ( op ) =>
      {
        let parsed = JSON.parse( op.output );
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( parsed.output, '[ \'staging\', \'debug\', \'testArg1\', \'testArg2\' ]\n' )
        return null;
      })

      /* - */

      function testAppParent9()
      {
        let _ = require( toolsPath );
        _.include( 'wFiles' );
        _.include( 'wProcess' );

        let options =
        {
          execPath :  'node ' + programPath,
          args : [ 'staging', 'debug' ],
          mode : 'shell',
          passingThrough : 1,
          stdio : 'pipe',
          outputPiping : 0,
          outputCollecting : 1,
          applyingExitCode : 0,
          throwingExitCode : 1,
          inputMirroring : 0
        }

        return _.process.start( options )
        .then( ( op ) =>
        {
          console.log( JSON.stringify({ output : op.output }) );
          return null;
        })
      }
    })

    a.ready.then( () =>
    {
      test.close( '2 args to parent process' );
      return null;
    } );

    /* - */

    a.ready.then( () =>
    {
      test.open( '3 args to parent process' );
      return null;
    } );

    a.ready.then( () =>
    {
      test.case = 'args to child : none; args to parent : parentA, parentB, parentC';

      let o =
      {
        execPath : testAppPath2,
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        args : [ 'parentA', 'parentB', 'parentC' ],
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'parentA', 'parentB', 'parentC' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child : a; args to parent : parentA, parentB, parentC';

      let o =
      {
        execPath : testAppPath2,
        args : 'a',
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        args : [ 'parentA', 'parentB', 'parentC' ],
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'parentA', 'parentB', 'parentC' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /*  */

    a.ready.then( () =>
    {
      test.case = 'args to child : a, b, c; args to parent : parentA, parentB, parentC';

      let o =
      {
        execPath : testAppPath2,
        args : [ 'a', 'b', 'c' ],
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1,
        mode : 'spawn',
        args : [ 'parentA', 'parentB', 'parentC' ],
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'b', 'c', 'parentA', 'parentB', 'parentC' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child in execPath: a, b, c; args to parent in execPath : parentA, parentB, parentC';

      let o =
      {
        execPath : testAppPath2 + ' a b c',
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1 + ' parentA parentB parentC',
        mode : 'spawn',
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'b', 'c', 'parentA', 'parentB', 'parentC' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    /* */

    a.ready.then( () =>
    {
      test.case = 'args to child in args : a and execPath: b, c; args to parent in args : parentA and in execPath : parentB, parentC';

      let o =
      {
        execPath : testAppPath2 + ' a',
        args : [ 'b', 'c' ],
        outputCollecting : 0,
        outputPiping : 0,
        mode : 'fork',
        throwingExitCode : 0,
        applyingExitCode : 0,
        stdio : 'inherit'
      }
      a.fileProvider.fileWrite({ filePath : a.abs( 'op.json' ), data : o, encoding : 'json' });

      let o2 =
      {
        execPath : 'node ' + testAppPath1 + ' parentA',
        mode : 'spawn',
        args : [ 'parentB', 'parentC' ],
        stdio : 'pipe',
        outputPiping : 1,
        outputCollecting : 1,
      }
      _.process.start( o2 );

      o2.conTerminate.then( () =>
      {
        test.il( o2.output, `[ 'a', 'b', 'c', 'parentA', 'parentB', 'parentC' ]\n` );
        return null;
      });

      return o2.conTerminate;
    })

    a.ready.then( () =>
    {
      test.close( '3 args to parent process' );
      return null;
    } )

  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    _.include( 'wFiles' );
    _.include( 'wProcess' );

    let o = _.fileProvider.fileRead({ filePath : _.path.join( __dirname, 'op.json' ), encoding : 'json' });
    o.currentPath = __dirname;
    _.process.startPassingThrough( o );
  }

  function program2()
  {
    let _ = require( toolsPath );
    _.include( 'wFiles' );
    _.include( 'wProcess' );

    console.log( process.argv.slice( 2 ) );
  }
}

// --
// termination
// --

function exitReason( test )
{
  test.case = 'initial value'
  var got = _.process.exitReason();
  test.identical( got, null );

  /* */

  test.case = 'set reason'
  _.process.exitReason( 'reason' );
  var got = _.process.exitReason();
  test.identical( got, 'reason' );

  /* */

  test.case = 'update reason'
  _.process.exitReason( 'reason2' );
  var got = _.process.exitReason();
  test.identical( got, 'reason2' );
}

//

/* qqq for Yevhen : poor tests, please extend it */
function exitCode( test )
{
  let context = this;
  let a = test.assetFor( false );

  test.case = 'initial value'
  var got = _.process.exitCode();
  test.identical( got, 0 );

  /* */

  test.case = 'set code'
  _.process.exitCode( 1 );
  var got = _.process.exitCode();
  test.identical( got, 1 );

  /* */

  test.case = 'update reason'
  _.process.exitCode( 2 );
  var got = _.process.exitCode();
  test.identical( got, 2 );

  // /* */

  // test.case = 'update reason, set exitCode to 3'
  // _.process.exitCode( 3 );
  // var got = _.process.exitCode();
  // test.identical( got, 3 );

  // /* */

  // test.case = 'update reason, set exitCode to 4'
  // _.process.exitCode( 4 );
  // var got = _.process.exitCode();
  // test.identical( got, 4 );

  // /* */

  // test.case = 'update reason, set exitCode to 5'
  // _.process.exitCode( 5 );
  // var got = _.process.exitCode();
  // test.identical( got, 5 );

  // /* */

  // test.case = 'update reason, set exitCode to 6'
  // _.process.exitCode( 6 );
  // var got = _.process.exitCode();
  // test.identical( got, 6 );

  // /* */

  // test.case = 'update reason, set exitCode to 7'
  // _.process.exitCode( 7 );
  // var got = _.process.exitCode();
  // test.identical( got, 7 );

  // /* */

  // test.case = 'update reason, set exitCode to 8'
  // _.process.exitCode( 8 );
  // var got = _.process.exitCode();
  // test.identical( got, 8 );

  // /* */

  // test.case = 'update reason, set exitCode to 9'
  // _.process.exitCode( 9 );
  // var got = _.process.exitCode();
  // test.identical( got, 9 );

  // /* */

  // test.case = 'update reason, set exitCode to 10'
  // _.process.exitCode( 10 );
  // var got = _.process.exitCode();
  // test.identical( got, 10 );

  // /* */

  // test.case = 'update reason, set exitCode to 11'
  // _.process.exitCode( 11 );
  // var got = _.process.exitCode();
  // test.identical( got, 11 );

  // /* */

  // test.case = 'update reason, set exitCode to 12'
  // _.process.exitCode( 12 );
  // var got = _.process.exitCode();
  // test.identical( got, 12 );

  // /* */

  // test.case = 'update reason, set exitCode to 129'
  // _.process.exitCode( 129 )
  // var got = _.process.exitCode()
  // test.il( got, 129 )

  /* */

  a.ready.then( () =>
  {
    test.case = 'wrong execPath'

    return _.process.start({ execPath : '1', throwingExitCode : 0 })
    .then( ( op ) =>
    {
      test.il( op.exitCode, 127 );
      test.il( op.ended, true );
      return null;
    } )
  })

  /* */

  a.ready.then( () =>
  {
    test.case = 'uncaught fatal exception'
    let programPath = a.program( testApp );
    let options =
    {
      execPath : 'node ' + programPath,
      throwingExitCode : 0
    }
    return _.process.start( options )
    .then( ( op ) =>
    {
      test.il( op.exitCode, 1 );
      test.il( op.ended, true );
      return null;
    } )

    function testApp()
    {
      asasdasd
    }
  })

  /* */

  a.ready.then( () =>
  {
    test.case = 'throw error in app';
    let programPath = a.program( testApp2 );
    let options =
    {
      execPath : 'node ' + programPath,
      throwingExitCode : 0
    }
    return _.process.start( options )
    .then( ( op ) =>
    {
      test.il( op.exitCode, 1 );
      test.il( op.ended, true );
      return null;
    } )

    function testApp2()
    {
      throw new Error();
    }
  })

  /* */

  a.ready.then( () =>
  {
    test.case = 'error in subprocess process ( uncaught asynchronous error )';
    let programPath = a.program( testApp3 );
    let options =
    {
      execPath : 'node ' + programPath,
      throwingExitCode : 0
    }
    return _.process.start( options )
    .then( ( op ) =>
    {
      test.il( op.exitCode, 255 );
      test.il( op.ended, true );
      return null;
    } )

    function testApp3()
    {
      let _ = require( toolsPath );
      _.include( 'wProcess' );
      _.include( 'wFiles' );

      return _.process.start()
    }
  })

  /* */

  a.ready.then( () =>
  {
    test.case = 'explicitly exit with code : 100';
    let programPath = a.program( testApp4 );
    let options =
    {
      execPath : 'node ' + programPath,
      throwingExitCode : 0
    }
    return _.process.start( options )
    .then( ( op ) =>
    {
      test.il( op.exitCode, 100 );
      test.il( op.ended, true );
      return null;
    } )

    function testApp4()
    {
      let _ = require( toolsPath );
      _.include( 'wProcess' );
      _.include( 'wFiles' );

      return _.process.exit( 100 );
    }
  })

  /* */

  test.case = 'change to zero'
  _.process.exitCode( 0 );
  var got = _.process.exitCode();
  test.identical( got, 0 );

  return a.ready;

}

//

function pidFrom( test )
{
  let o =
  {
    execPath : 'node -v',
  }
  let ready = _.process.start( o );
  let expected = o.process.pid;

  test.identical( _.process.pidFrom( o ), expected )
  test.identical( _.process.pidFrom( o.process ), expected )
  test.identical( _.process.pidFrom( o.process.pid ), expected )

  if( !Config.debug )
  return ready;

  test.shouldThrowErrorSync( () => _.process.pidFrom() );
  test.shouldThrowErrorSync( () => _.process.pidFrom( [] ) );
  test.shouldThrowErrorSync( () => _.process.pidFrom( {} ) );
  test.shouldThrowErrorSync( () => _.process.pidFrom( { pnd : {} } ) );
  test.shouldThrowErrorSync( () => _.process.pidFrom( '123' ) );

  return ready;
}

//

function isAlive( test )
{
  let track = [];
  let o =
  {
    execPath : `node -e "setTimeout( () => { console.log( 'child terminate' ) }, 3000 )"`,
  }
  _.process.start( o );

  o.conStart.then( () =>
  {
    track.push( 'conStart' );
    test.identical( _.process.isAlive( o ), true );
    test.identical( _.process.isAlive( o.process ), true );
    test.identical( _.process.isAlive( o.process.pid ), true );
    return null;
  })

  o.conTerminate.then( () =>
  {
    track.push( 'conTerminate' );
    test.identical( _.process.isAlive( o ), false );
    test.identical( _.process.isAlive( o.process ), false );
    test.identical( _.process.isAlive( o.process.pid ), false );
    test.identical( track, [ 'conStart', 'conTerminate' ] )
    return null;
  })

  let ready = _.Consequence.AndKeep( o.conStart, o.conTerminate );

  if( !Config.debug )
  return ready;

  ready.then( () =>
  {
    test.shouldThrowErrorSync( () => _.process.isAlive() );
    test.shouldThrowErrorSync( () => _.process.isAlive( [] ) );
    test.shouldThrowErrorSync( () => _.process.isAlive( {} ) );
    test.shouldThrowErrorSync( () => _.process.isAlive( { pnd : {} } ) );
    test.shouldThrowErrorSync( () => _.process.isAlive( '123' ) );

    return null;
  })

  return ready;
}

//

function statusOf( test )
{
  let o =
  {
    execPath : `node -e "setTimeout( () => { console.log( 'child terminate' ) }, 3000 )"`,
  }
  let track = [];
  _.process.start( o );

  o.conStart.then( () =>
  {
    track.push( 'conStart' )
    test.identical( _.process.statusOf( o ), 'alive' );
    test.identical( _.process.statusOf( o.process ), 'alive' );
    test.identical( _.process.statusOf( o.process.pid ), 'alive' );
    return null;
  })

  o.conTerminate.then( () =>
  {
    track.push( 'conTerminate' );
    test.identical( _.process.statusOf( o ), 'dead' );
    test.identical( _.process.statusOf( o.process ), 'dead' );
    test.identical( _.process.statusOf( o.process.pid ), 'dead' );
    test.identical( track, [ 'conStart', 'conTerminate' ] );
    return null;
  })

  let ready = _.Consequence.AndKeep( o.conStart, o.conTerminate );

  if( !Config.debug )
  return ready;

  ready.then( () =>
  {
    test.shouldThrowErrorSync( () => _.process.statusOf() );
    test.shouldThrowErrorSync( () => _.process.statusOf( [] ) );
    test.shouldThrowErrorSync( () => _.process.statusOf( {} ) );
    test.shouldThrowErrorSync( () => _.process.statusOf( { pnd : {} } ) );
    test.shouldThrowErrorSync( () => _.process.statusOf( '123' ) );

    return null;
  })

  return ready;
}

//

function kill( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  /* */

  var expectedOutput = testAppPath + '\n';

  /* */

  a.ready

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1000, () => _.process.kill( o.process ) )

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGKILL' );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1000, () => _.process.kill( o.process.pid ) )

    ready.then( ( op ) =>
    {
      if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 1 );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, null );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGKILL' );
      }

      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* fork */

  .then( () =>
  {
    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1000, () => _.process.kill( o.process ) )

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGKILL' );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1000, () => _.process.kill( o.process.pid ) )

    ready.then( ( op ) =>
    {
      if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 1 );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, null );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGKILL' );
      }

      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* shell */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1000, () => _.process.kill( o.process ) )

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGKILL' );
      if( process.platform === 'darwin' )
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      else
      test.is( _.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1000, () => _.process.kill( o.process.pid ) )

    ready.then( ( op ) =>
    {
      if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 1 );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, null );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGKILL' );
      }

      if( process.platform === 'darwin' )
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      else
      test.is( _.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  // zzz for Vova : find how to simulate EPERM error using process.kill and write test case

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    setTimeout( () =>
    {
      console.log( 'Application timeout!' )
    }, 5000 )
  }
}

//

/* qqq for Yevhen : subroutine for modes */
function killSync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  /* */

  a.ready

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );

    ready.then( ( op ) =>
    {

      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGKILL' );
      test.identical( op.ended, true );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.kill({ pnd : o.process, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      test.is( !_.process.isAlive( o.process.pid ) ); debugger;

      result.then( ( arg ) =>
      {
        test.identical( arg, true );
        return ready;
      })

      return result;
    })
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    ready.then( ( op ) =>
    {
      if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 1 );
        test.identical( op.exitSignal, null );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.exitSignal, 'SIGKILL' );
      }

      test.identical( op.ended, true );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.kill({ pid : o.process.pid, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      test.is( !_.process.isAlive( o.process.pid ) );

      result.then( ( arg ) =>
      {
        test.identical( arg, true );
        return ready;
      })

      return result;
    })
  })

  /* fork */

  .then( () =>
  {
    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGKILL' );
      test.identical( op.ended, true );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.kill({ pnd : o.process, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      test.is( !_.process.isAlive( o.process.pid ) );

      result.then( ( arg ) =>
      {
        test.identical( arg, true );
        return ready;
      })

      return result;
    })

  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    ready.then( ( op ) =>
    {
      if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 1 );
        test.identical( op.exitSignal, null );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.exitSignal, 'SIGKILL' );
      }

      test.identical( op.ended, true );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.kill({ pid : o.process.pid, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      test.is( !_.process.isAlive( o.process.pid ) );

      result.then( ( arg ) =>
      {
        test.identical( arg, true );
        return ready;
      })

      return result;
    })

  })

  /* shell */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    ready.then( ( op ) =>
    {
      if( process.platform === 'win32')
      {
        test.identical( op.exitCode, 1 );
        test.identical( op.exitSignal, null );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.exitSignal, 'SIGKILL' );
      }

      test.identical( op.ended, true );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.kill({ pnd : o.process, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      test.is( !_.process.isAlive( o.process.pid ) );

      result.then( ( arg ) =>
      {
        test.identical( arg, true );
        return ready;
      })

      return result;
    })
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    ready.then( ( op ) =>
    {
      if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 1 );
        test.identical( op.exitSignal, null );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.exitSignal, 'SIGKILL' );
      }

      test.identical( op.ended, true );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );

      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.kill({ pid : o.process.pid, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      test.is( !_.process.isAlive( o.process.pid ) );

      result.then( ( arg ) =>
      {
        test.identical( arg, true );
        return ready;
      })

      return result;
    })
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    setTimeout( () =>
    {
      console.log( 'Application timeout!' )
    }, context.t2 )
  }
}

//

function killOptionWithChildren( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );
  let testAppPath3 = a.program( testApp3 );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'child -> child, kill first child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid, killed;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      killed = _.process.kill({ pid : o.process.pid, withChildren : 1 });
    })

    a.ready.then( ( op ) =>
    {
      return killed.then( () =>
      {
        if( process.platform === 'win32' )
        {
          test.identical( op.exitCode, 1 );
          test.identical( op.ended, true );
          test.identical( op.exitSignal, null );
        }
        else
        {
          test.identical( op.exitCode, null );
          test.identical( op.ended, true );
          test.identical( op.exitSignal, 'SIGKILL' );
        }
        test.identical( _.strCount( op.output, 'Application timeout' ), 0 );
        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( lastChildPid ) );
        return null;
      })
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    test.case = 'child -> child, kill last child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid, killed;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      killed = _.process.kill({ pid : lastChildPid, withChildren : 1 });
    })

    ready.then( ( op ) =>
    {
      return killed.then( () =>
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.identical( _.strCount( op.output, 'Application timeout' ), 0 );
        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( lastChildPid ) );
        return null;
      })
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    test.case = 'parent -> child*'
    var o =
    {
      execPath : 'node ' + testAppPath3,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, killed;

    o.process.on( 'message', ( e ) =>
    {
      children = e.map( ( src ) => _.numberFrom( src ) )
      killed = _.process.kill({ pid : o.process.pid, withChildren : 1 });
    })

    ready.then( ( op ) =>
    {
      return killed.then( () =>
      {
        if( process.platform === 'win32' )
        {
          test.identical( op.exitCode, 1 );
          test.identical( op.ended, true );
          test.identical( op.exitSignal, null );
        }
        else
        {
          test.identical( op.exitCode, null );
          test.identical( op.ended, true );
          test.identical( op.exitSignal, 'SIGKILL' );
        }
        test.identical( _.strCount( op.output, 'Application timeout' ), 0 );
        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( children[ 0 ] ) )
        test.is( !_.process.isAlive( children[ 1 ] ) );
        return null;
      })
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    test.case = 'parent -> detached'
    var o =
    {
      execPath : 'node ' + testAppPath3 + ' detached',
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, killed;
    o.process.on( 'message', ( e ) =>
    {
      children = e.map( ( src ) => _.numberFrom( src ) )
      killed = _.process.kill({ pid : o.process.pid, withChildren : 1 });
    })

    ready.then( ( op ) =>
    {
      return killed.then( () =>
      {
        if( process.platform === 'win32' )
        {
          test.identical( op.exitCode, 1 );
          test.identical( op.ended, true );
          test.identical( op.exitSignal, null );
        }
        else
        {
          test.identical( op.exitCode, null );
          test.identical( op.ended, true );
          test.identical( op.exitSignal, 'SIGKILL' );
        }
        test.identical( _.strCount( op.output, 'Application timeout' ), 0 );
        test.is( !_.process.isAlive( o.process.pid ) );
        test.is( !_.process.isAlive( children[ 0 ] ) )
        test.is( !_.process.isAlive( children[ 1 ] ) );
        return null;
      })
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    test.case = 'process is not running';
    var o =
    {
      execPath : 'node ' + testAppPath2,
      mode : 'spawn',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o );
    o.process.kill('SIGKILL');

    return o.ready.then( () =>
    {
      let ready = _.process.kill({ pid : o.process.pid, withChildren : 1 });
      return test.shouldThrowErrorAsync( ready );
    })

  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    var o =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      stdio : 'inherit',
      outputPiping : 0,
      outputCollecting : 0,
      inputMirroring : 0,
      throwingExitCode : 0
    }
    _.process.start( o );
    process.send( o.process.pid )
  }

  function testApp2()
  {
    if( process.send )
    process.send( process.pid );
    setTimeout( () => { console.log( 'Application timeout' ) }, 5000 )
  }

  function testApp3()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    let detaching = process.argv[ 2 ] === 'detached';
    var o1 =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      detaching,
      inputMirroring : 0,
      throwingExitCode : 0
    }
    _.process.start( o1 );
    var o2 =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      detaching,
      inputMirroring : 0,
      throwingExitCode : 0
    }
    _.process.start( o2 );
    process.send( [ o1.process.pid, o2.process.pid ] )
  }

}

//

function terminate( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctrly on node 14
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  a.ready

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( op.ended, true );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.on( 'message', () =>
    {
      _.process.terminate( o.process.pid );
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( op.ended, true );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* fork */

  .then( () =>
  {
    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.on( 'message', () =>
    {
      _.process.terminate( o.process.pid );
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( op.ended, true );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( op.ended, true );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /* shell */

  /*
    zzz Vova: shell,exec modes have different behaviour on Windows,OSX and Linux
    look for solution that allow to have same behaviour on each mode
  */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.stdout.on( 'data', ( data ) =>
    {
      data = data.toString();
      if( _.strHas( data, 'ready' ))
      _.process.terminate({ pnd : o.process, timeOut : 0 });
    })

    ready.then( ( op ) =>
    {
      if( process.platform === 'linux' ) /* xxx qqq : ? */
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'SIGTERM' ) );
        test.is( !_.strHas( op.output, 'Application timeout!' ) );
      }

      return null;
    })

    return ready;
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.stdout.on( 'data', ( data ) =>
    {
      data = data.toString();
      if( _.strHas( data, 'ready' ))
      _.process.terminate({ pid : o.process.pid, timeOut : 0 });
    })

    ready.then( ( op ) =>
    {
      if( process.platform === 'linux' )
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'SIGTERM' ) );
        test.is( !_.strHas( op.output, 'Application timeout!' ) );
      }
      return null;
    })

    return ready;
  })

  /*
    zzz Vova: shell,exec modes have different behaviour on Windows,OSX and Linux
    look for solution that allow to have same behaviour on each mode
  */

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.process._exitHandlerRepair();
    if( process.send )
    process.send( process.pid );
    else
    console.log( 'ready' );
    setTimeout( () =>
    {
      console.log( 'Application timeout!' )
    }, 5000 )
  }
}

//

function terminateSync( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctrly on node 14
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 );
  //   return;
  // }

  a.ready

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o );

    o.conTerminate.then( ( op ) =>
    {
      test.identical( op.ended, true );
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.terminate({ pnd : o.process, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      let got = result.sync();
      test.identical( got, true );
      return o.conTerminate;
    })
  })

  /* */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o );

    o.conTerminate.then( ( op ) =>
    {
      test.identical( op.ended, true );
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.terminate({ pid : o.process.pid, sync : 1  });
      test.identical( result.resourcesCount(), 1 );
      let got = result.sync();
      test.identical( got, true );
      return o.conTerminate;
    })
  })

  /* fork */

  .then( () =>
  {

    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o )

    o.conTerminate.then( ( op ) =>
    {
      test.identical( op.ended, true );
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.terminate({ pid : o.process.pid, sync : 1  });
      test.identical( result.resourcesCount(), 1 );
      let got = result.sync();
      test.identical( got, true );
      return o.conTerminate;
    })
  })

  /* */

  .then( () =>
  {
    let ready = _.Consequence();

    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o )

    o.conTerminate.then( ( op ) =>
    {
      test.identical( op.ended, true );
      test.identical( op.exitCode, null );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.terminate({ pnd : o.process, sync : 1  });
      test.identical( result.resourcesCount(), 1 );
      let got = result.sync();
      test.identical( got, true );
      return o.conTerminate;
    })
  })

  /* shell */

  /*
    zzz Vova: shell,exec modes have different behaviour on Windows,OSX and Linux
    look for solution that allow to have same behaviour on each mode
  */

  .then( () =>
  {

    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o )

    o.conTerminate.then( ( op ) =>
    {
      if( process.platform === 'linux' )
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'SIGTERM' ) );
        test.is( !_.strHas( op.output, 'Application timeout!' ) );
      }

      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.terminate({ pnd : o.process, timeOut : 0, sync : 1  });
      test.identical( result.resourcesCount(), 1 );
      let got = result.sync();
      test.identical( got, true );
      return o.conTerminate;
    })
  })

  /* */

  .then( () =>
  {

    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o )

    o.conTerminate.then( ( op ) =>
    {
      if( process.platform === 'linux' )
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else if( process.platform === 'win32' )
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else
      {
        test.identical( op.exitCode, 0 );
        test.identical( op.exitSignal, null );
        test.identical( op.exitReason, 'normal' );
        test.identical( op.ended, true );
        test.identical( op.state, 'terminated' );
        test.is( _.strHas( op.output, 'SIGTERM' ) );
        test.is( !_.strHas( op.output, 'Application timeout!' ) );
      }

      return null;
    })

    return _.time.out( context.t1, () =>
    {
      let result = _.process.terminate({ pid : o.process.pid, timeOut : 0, sync : 1 });
      test.identical( result.resourcesCount(), 1 );
      let got = result.sync();
      test.identical( got, true );
      return o.conTerminate;
    })
  })

  /*
    zzz Vova: shell,exec modes have different behaviour on Windows,OSX and Linux
    look for solution that allow to have same behaviour on each mode
  */

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.process._exitHandlerRepair();
    if( process.send )
    process.send( process.pid );
    else
    console.log( 'ready' );
    setTimeout( () =>
    {
      console.log( 'Application timeout!' )
    }, 5000 )
  }
}

//

function startErrorAfterTerminationWithSend( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );
  let track;

  let modes = [ 'fork', 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => run( mode ) ) );
  return a.ready;

  /* */

  function run( mode )
  {
    track = [];

    var o =
    {
      execPath : mode !== 'fork' ? 'node' : null,
      args : [ testAppPath ],
      mode,
      ipc : 1,
    }

    _.process.on( 'uncaughtError', uncaughtError_functor( mode ) );

    let result = _.process.start( o );

    o.conStart.then( ( arg ) =>
    {
      track.push( 'conStart' );
      return null
    });

    o.conTerminate.finally( ( err, op ) =>
    {
      track.push( 'conTerminate' );
      test.identical( err, undefined );
      test.identical( op, o );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );

      test.description = 'Attempt to send data when ipc channel is closed';
      o.process.send( 1 );

      return null;
    })

    return _.time.out( 10000, () =>
    {
      test.identical( track, [ 'conStart', 'conTerminate', 'uncaughtError' ] );
      test.identical( o.ended, true );
      test.identical( o.state, 'terminated' );
      test.identical( o.error, null );
      test.identical( o.exitCode, 0 );
      test.identical( o.exitSignal, null );
      test.identical( o.exitReason, 'normal' );
      test.identical( o.process.exitCode, 0 );
      test.identical( o.process.signalCode, null );
    });

  }

  /* - */

  function testApp()
  {
    setTimeout( () => {}, 1000 );
  }

  function uncaughtError_functor( mode )
  {
    return function uncaughtError( e )
    {
      var exp =
  `
  Channel closed
  `
    if( process.platform === 'darwin' )
    exp += `code : 'ERR_IPC_CHANNEL_CLOSED'` + exp;

    exp +=
`
  Error starting the process
      Exec path : ${ mode === 'fork' ? '' : 'node ' }${a.abs( 'testApp.js' )}
      Current path : ${a.path.current()}
`
    test.equivalent( e.err.originalMessage, exp )
    _.errAttend( e.err );
    track.push( 'uncaughtError' );
    _.process.off( 'uncaughtError', uncaughtError );
    }
  }

}

startErrorAfterTerminationWithSend.description =
`
  - handleClose receive error after termination of the process
  - error caused by call o.process.send()
  - throws asynchronouse uncahught error
`

//

function startTerminateHangedWithExitHandler( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  // if( process.platform === 'win32' )
  // {
  //   // zzz: windows-kill doesn't work correctrly on node 14
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  a.ready

  .then( () =>
  {
    let o =
    {
      execPath : 'node ' + testAppPath,
      mode : 'spawn',
      throwingExitCode : 0,
      outputPiping : 0,
      ipc : 1,
      outputCollecting : 1,
    }

    let con = _.process.start( o );

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process, timeOut : 5000 });
    })

    con.then( () =>
    {
      test.identical( o.exitCode, null );
      test.identical( o.exitSignal, 'SIGKILL' );
      test.is( !_.strHas( o.output, 'SIGTERM' ) );

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    let o =
    {
      execPath : testAppPath,
      mode : 'fork',
      throwingExitCode : 0,
      outputPiping : 0,
      ipc : 1,
      outputCollecting : 1,
    }

    let con = _.process.start( o );

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process, timeOut : 5000 });
    })

    con.then( () =>
    {
      test.identical( o.exitCode, null );
      test.identical( o.exitSignal, 'SIGKILL' );
      test.is( !_.strHas( o.output, 'SIGTERM' ) );

      return null;
    })

    return con;
  })

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.process._exitHandlerRepair();
    process.send( process.pid )
    while( 1 )
    {
      console.log( _.time.now() )
    }
  }
}

startTerminateHangedWithExitHandler.timeOut = 20000;

/* startTerminateHangedWithExitHandler.description =
`
  Test app - code that blocks event loop and appExitHandlerRepair called at start

  Will test:
    - Termination of child process using SIGINT signal after small delay
    - Termination of child process using SIGKILL signal after small delay

  Expected behaviour:
    - For SIGINT: Child was terminated with exitCode : 0, exitSignal : null
    - For SIGKILL: Child was terminated with exitCode : null, exitSignal : SIGKILL
    - No time out message in output
` */

//

function startTerminateAfterLoopRelease( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  // if( process.platform === 'win32' )
  // {
  //   // zzz: windows-kill doesn't work correctrly on node 14
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  a.ready

  .then( () =>
  {
    let o =
    {
      execPath : 'node ' + testAppPath,
      mode : 'spawn',
      throwingExitCode : 0,
      outputPiping : 0,
      ipc : 1,
      outputCollecting : 1,
    }

    let con = _.process.start( o );

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process, timeOut : 10000 });
    })

    con.then( () =>
    {
      test.identical( o.exitCode, null );
      test.identical( o.exitSignal, 'SIGKILL' );
      test.is( !_.strHas( o.output, 'SIGTERM' ) );
      test.is( !_.strHas( o.output, 'Exit after release' ) );

      return null;
    })

    return con;
  })

  /*  */

  .then( () =>
  {
    let o =
    {
      execPath : testAppPath,
      mode : 'fork',
      throwingExitCode : 0,
      outputPiping : 0,
      ipc : 1,
      outputCollecting : 1,
    }

    let con = _.process.start( o );

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process, timeOut : 10000 });
    })

    con.then( () =>
    {
      test.identical( o.exitCode, null );
      test.identical( o.exitSignal, 'SIGKILL' );
      test.is( !_.strHas( o.output, 'SIGTERM' ) );
      test.is( !_.strHas( o.output, 'Exit after release' ) );

      return null;
    })

    return con;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );

    _.include( 'wProcess' );
    _.process._exitHandlerRepair();
    let loop = true;
    setTimeout( () =>
    {
      loop = false;
    }, 5000 )
    process.send( process.pid );
    while( loop )
    {
      loop = loop;
    }
    console.log( 'Exit after release' );
  }
}

startTerminateAfterLoopRelease.description =
`
  Test app - code that blocks event loop for short period of time and appExitHandlerRepair called at start

  Will test:
    - Termination of child process using SIGINT signal after small delay

  Expected behaviour:
    - Child was terminated after event loop release with exitCode : 0, exitSignal : null
    - Child process message should be printed
`

//

function endSignalsBasic( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( program1 );
  let o3 =
  {
    outputPiping : 1,
    outputCollecting : 1,
    applyingExitCode : 0,
    throwingExitCode : 0,
    stdio : 'pipe',
  }

  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGQUIT' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGINT' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGTERM' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalKilling( mode, 'SIGKILL' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => terminate( mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => terminateShell( mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => kill( mode ) ) );
  return a.ready;

  /* --- */

  function signalTerminating( mode, signal )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
${signal}
`
        var exp2 =
`program1:begin
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withSleep:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
`
        var exp2 =
`program1:begin
sleep:begin
sleep:end
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        console.log( `dtime:${dtime}` );
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withSleep:1 withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1`, `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
sleep:end
program1:end
${signal}
`
        var exp2 =
`program1:begin
sleep:begin
sleep:end
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        console.log( `dtime:${dtime}` );
        test.ge( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withDeasync:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withDeasync:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
deasync:begin
${signal}
`
        var exp2 =
`program1:begin
deasync:begin
program1:end
deasync:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        console.log( `dtime:${dtime}` );
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function signalKilling( mode, signal )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withSleep:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
`
        var exp2 =
`program1:begin
sleep:begin
sleep:end
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withSleep:1 withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1`, `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
`
        var exp2 =
`program1:begin
sleep:begin
sleep:end
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, ${signal}, withDeasync:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withDeasync:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
deasync:begin
`
        var exp2 =
`program1:begin
deasync:begin
program1:end
deasync:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function terminate( mode )
  {
    let ready = _.Consequence().take( null );

    if( mode === 'shell' )
    return ready;

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
SIGTERM
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withSleep:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withSleep:1 withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1`, `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
sleep:end
program1:end
SIGTERM
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.ge( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withDeasync:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withDeasync:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
deasync:begin
SIGTERM
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function terminateShell( mode )
  {
    let ready = _.Consequence().take( null );

    if( mode !== 'shell' )
    return ready;

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
Terminated
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, 143 );
        test.identical( options.exitSignal, null );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'code' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, 143 );
        test.identical( options.process.signalCode, null );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
SIGTERM
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withSleep:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
Terminated
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, 143 );
        test.identical( options.exitSignal, null );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'code' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, 143 );
        test.identical( options.process.signalCode, null );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withSleep:1 withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1`, `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
sleep:end
program1:end
SIGTERM
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.ge( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, terminate, withDeasync:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withDeasync:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
deasync:begin
SIGTERM
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function kill( mode )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, kill`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.kill( options.process.pid );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGKILL' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGKILL' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, kill withTools:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withTools:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.kill( options.process.pid );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGKILL' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGKILL' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, kill withSleep:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withSleep:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.kill( options.process.pid );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
`
        var exp2 =
`program1:begin
sleep:begin
sleep:end
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGKILL' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGKILL' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, kill withTools:1 withSleep:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withTools:1`, `withSleep:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.kill( options.process.pid );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
sleep:begin
`
        var exp2 =
`program1:begin
sleep:begin
sleep:end
program1:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGKILL' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGKILL' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* */

    .then( function( arg )
    {
      test.case = `mode:${mode}, kill withDeasync:1`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ `withDeasync:1` ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.kill( options.process.pid );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
deasync:begin
`
        var exp2 =
`program1:begin
deasync:begin
program1:end
deasync:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGKILL' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGKILL' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        if( mode !== 'shell' )
        test.le( dtime, context.t1*3 );
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function program1()
  {
    console.log( 'program1:begin' );

    let withSleep = process.argv.includes( 'withSleep:1' );
    let withTools = process.argv.includes( 'withTools:1' );
    let withDeasync = process.argv.includes( 'withDeasync:1' );

    // console.log( `withSleep:${withSleep} withTools:${withTools} withDeasync:${withDeasync}` );

    if( withTools || withDeasync )
    {
      let _ = require( toolsPath );
      _.include( 'wProcess' );
      _.process._exitHandlerRepair();
    }

    setTimeout( () => { console.log( 'program1:end' ) }, context.t1*2 );

    if( withSleep )
    sleep( context.t1*4 );

    if( withDeasync )
    deasync( context.t1*4 );

    function onTime()
    {
      console.log( 'time:end' );
    }

    function sleep( delay )
    {
      console.log( 'sleep:begin' );
      let now = Date.now();
      while( ( Date.now() - now ) < delay )
      {
        // if( Math.random() < 0.001 )
        // console.log( Date.now() - now );
      }
      console.log( 'sleep:end' );
    }

    function deasync( delay )
    {
      let _ = wTools;
      console.log( 'deasync:begin' );
      let con = new _.Consequence().take( null );
      con.timeOut( delay ).deasync();
      console.log( 'deasync:end' );
    }

    function handlersRemove()
    {
      process.removeAllListeners( 'SIGINT' );
      process.removeAllListeners( 'SIGQUIT' );
      process.removeAllListeners( 'SIGTERM' );
      process.removeAllListeners( 'exit' );
    }

  }

}

endSignalsBasic.timeOut = 300000;
endSignalsBasic.description =
`
  - signals terminate or kill started process
`

/* zzz : find a way to really freeze a process to test routine _.process.terminate() with timeout */

//

function endSignalsOnExit( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( program1 );
  let o3 =
  {
    outputPiping : 1,
    outputCollecting : 1,
    applyingExitCode : 0,
    throwingExitCode : 0,
    stdio : 'pipe',
  }

  let modes = [ 'fork', 'spawn', 'shell' ];
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGQUIT' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGINT' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGTERM' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalKilling( mode, 'SIGKILL' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => terminate( mode ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => kill( mode ) ) );
  return a.ready;

  /* --- */

  function signalTerminating( mode, signal )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, withExitHandler:1, withTools:1, ${signal}`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ 'withExitHandler:1', 'withTools:1' ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
${signal}
exit:end
`
        var exp2 =
`program1:begin
program1:end
exit:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function signalKilling( mode, signal )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, withExitHandler:1, withTools:1, ${signal}`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ 'withExitHandler:1', 'withTools:1' ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
program1:end
exit:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, signal );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, signal );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function terminate( mode )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, withExitHandler:1, withTools:1, terminate, pid`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ 'withExitHandler:1', 'withTools:1' ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pid : options.process.pid, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
SIGTERM
exit:end
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        return null;
      })

      return shell;
    })

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, withExitHandler:1, withTools:1, terminate, native descriptor`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ 'withExitHandler:1', 'withTools:1' ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.terminate({ pnd : options.process, withChildren : 1 });
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
SIGTERM
exit:end
`
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGTERM' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGTERM' );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function kill( mode )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, withExitHandler:1, withTools:1, kill, pid`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ 'withExitHandler:1', 'withTools:1' ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.kill( options.process.pid );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
Killed
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGKILL' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGKILL' );
        test.identical( options.process.killed, false );
        var dtime = _.time.now() - time1;
        return null;
      })

      return shell;
    })

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, withExitHandler:1, withTools:1, kill, native descriptor`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ 'withExitHandler:1', 'withTools:1' ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        _.process.kill( options.process );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
`
        var exp2 =
`program1:begin
Killed
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, null );
        test.identical( options.exitSignal, 'SIGKILL' );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'signal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, null );
        test.identical( options.process.signalCode, 'SIGKILL' );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function program1()
  {

    console.log( 'program1:begin' );

    let withExitHandler = process.argv.includes( 'withExitHandler:1' );
    let withTools = process.argv.includes( 'withTools:1' );

    if( withTools )
    {
      let _ = require( toolsPath );
      _.include( 'wProcess' );
      _.process._exitHandlerRepair();
    }

    if( withExitHandler )
    process.once( 'exit', onExit );

    setTimeout( () => { console.log( 'program1:end' ) }, context.t1 );

    function onTime()
    {
      console.log( 'time:end' );
    }

    function onExit()
    {
      console.log( 'exit:end' );
    }

  }

}

endSignalsOnExit.description =
`
  - handler of the event "exit" should be called, despite of signal, unless signal is SIGKILL
`

//

function endSignalsOnExitExit( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let programPath = a.program( program1 );
  let o3 =
  {
    outputPiping : 1,
    outputCollecting : 1,
    applyingExitCode : 0,
    throwingExitCode : 0,
    stdio : 'pipe',
  }

  let modes = [ 'fork', 'spawn' ];
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGQUIT' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGINT' ) ) );
  modes.forEach( ( mode ) => a.ready.then( () => signalTerminating( mode, 'SIGTERM' ) ) );
  return a.ready;

  /* --- */

  function signalTerminating( mode, signal )
  {
    let ready = _.Consequence().take( null );

    /* - */

    ready

    /* - */

    .then( function( arg )
    {
      test.case = `mode:${mode}, withExitHandler:1, withTools:1, ${signal}`;

      var time1 = _.time.now();
      var o2 =
      {
        execPath : mode === `fork` ? `${programPath}` : `node ${programPath}`,
        args : [ 'withExitHandler:1', 'withTools:1' ],
        mode,
      }

      var options = _.mapSupplement( {}, o2, o3 );

      var shell = _.process.start( options );
      _.time.out( context.t1, () =>
      {
        test.identical( options.process.killed, false );
        options.process.kill( signal );
        return null;
      })
      shell.finally( function()
      {
        var exp1 =
`program1:begin
${signal}
exit:end
`
        var exp2 =
`program1:begin
program1:end
exit:end
`
        if( mode === 'shell' )
        test.is( options.output === exp1 || options.output === exp2 );
        else
        test.identical( options.output, exp1 );
        test.identical( options.exitCode, 0 );
        test.identical( options.exitSignal, null );
        test.identical( options.ended, true );
        test.identical( options.exitReason, 'normal' );
        test.identical( options.state, 'terminated' );
        test.identical( options.error, null );
        test.identical( options.process.exitCode, 0 );
        test.identical( options.process.signalCode, null );
        test.identical( options.process.killed, true );
        var dtime = _.time.now() - time1;
        return null;
      })

      return shell;
    })

    /* - */

    return ready;
  }

  /* -- */

  function program1()
  {

    console.log( 'program1:begin' );

    let withExitHandler = process.argv.includes( 'withExitHandler:1' );
    let withTools = process.argv.includes( 'withTools:1' );

    if( withTools )
    {
      let _ = require( toolsPath );
      _.include( 'wProcess' );
      _.process._exitHandlerRepair();
    }

    if( withExitHandler )
    process.once( 'exit', onExit );

    setTimeout( () => { console.log( 'program1:end' ) }, context.t1 );

    function onExit()
    {
      console.log( 'exit:end' );
      process.exit();
    }

  }

}

endSignalsOnExitExit.description =
`
  - handler of the event "exit" should be called exactly once
`

//

function terminateComplex( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctly in all scenarios
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'Sending signal to other process'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      _.process.terminate({ pid : lastChildPid });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( _.strCount( op.output, 'SIGTERM' ), 1 );
      test.identical( _.strCount( op.output, 'second child SIGTERM' ), 1 );
      test.is( !_.process.isAlive( o.process.pid ) )
      test.is( !_.process.isAlive( lastChildPid ) );
      return null;
    })

    return ready;
  })

  /*  */

  .then( () =>
  {
    test.case = 'Sending signal to child process has regular child process that should exit with parent'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      _.process.terminate({ pid : o.process.pid });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( _.strCount( op.output, 'SIGTERM' ), 1 );
      test.is( !_.process.isAlive( o.process.pid ) )
      test.is( !_.process.isAlive( lastChildPid ) );
      return null;
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'Sending signal to child process has regular child process that should exit with parent'
    var o =
    {
      execPath : testAppPath,
      mode : 'fork',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      _.process.terminate({ pid : o.process.pid });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.identical( _.strCount( op.output, 'SIGTERM' ), 1 );
      test.is( !_.process.isAlive( o.process.pid ) )
      test.is( !_.process.isAlive( lastChildPid ) );
      return null;
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'Sending signal to child process has regular child process that should exit with parent'
    var o =
    {
      execPath : 'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid;

    o.process.stdout.on( 'data', ( data ) =>
    {
      data = data.toString();
      lastChildPid = _.numberFrom( data );
      _.process.terminate({ pid : o.process.pid });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGTERM' );
      test.is( !_.process.isAlive( o.process.pid ) )
      test.is( !_.process.isAlive( lastChildPid ) );
      return null;
    })

    return ready;
  })

  /* - */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    let detaching = process.argv[ 2 ] === 'detached';
    var o =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      stdio : 'inherit',
      detaching,
      inputMirroring : 0,
      outputPiping : 0,
      outputCollecting : 0,
      throwingExitCode : 0
    }
    _.process.start( o );
    _.time.out( 1000, () =>
    {
      console.log( o.process.pid )
      if( process.send )
      process.send( o.process.pid )
    })
  }

  function testApp2()
  {
    process.on( 'SIGTERM', () =>
    {
      console.log( 'second child SIGTERM' )
      var fs = require( 'fs' );
      var path = require( 'path' )
      fs.writeFileSync( path.join( __dirname, process.pid.toString() ), process.pid.toString() )
      process.exit( 0 );
    })
    if( process.send )
    process.send( process.pid );
    setTimeout( () => {}, 5000 )
  }

}

terminateComplex.timeOut = 150000;

//

function terminateDetachedComplex( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( program1 );
  let testAppPath2 = a.program( program2 );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctly with detached processes
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  let modes = [ 'fork', 'spawn', 'shell' ];

  modes.forEach( ( modeParent ) =>
  {
    modes.forEach( ( modeChild ) =>
    {
      a.ready.then( () => run( modeParent, modeChild ) )
    })
  });
  return a.ready;

  /* - */

  function run( modeParent, modeChild )
  {
    let ready = _.Consequence().take( null )

    .then( () =>
    {
      test.case = `modeParent:${modeParent} modeChild:${modeChild} parent -> detached child, terminate withChildren : 0, detached child should stay alive`
      var o =
      {
        execPath : modeParent === 'fork' ? testAppPath : 'node ' + testAppPath,
        args : [ modeChild ],
        mode : modeParent,
        outputPiping : 1,
        outputCollecting : 1,
        throwingExitCode : 0
      }

      let childPid;
      let ready = _.Consequence();

      _.process.start( o );

      o.process.stdout.on( 'data', ( data ) =>
      {
        data = data.toString();
        if( _.strHas( data, 'ready' ) )
        ready.take( null );
      });

      ready.then( () =>
      {
        childPid = _.numberFrom( a.fileProvider.fileRead( a.abs( a.routinePath, 'childPID' ) ) );
        return _.process.terminate({ pnd : o.process, withChildren : 0 });
      });

      ready.then( () =>
      {
        test.identical( o.conTerminate.resourcesCount(), 1 );

        test.identical( o.exitCode, null );
        test.identical( o.exitSignal, 'SIGTERM' );
        test.identical( o.ended, true );
        test.is( _.strHas( o.output, 'SIGTERM' ) );
        test.is( !_.strHas( o.output, 'TerminationBegin' ) );
        test.is( !_.process.isAlive( _.numberFrom( o.process.pid ) ) );
        test.is( _.process.isAlive( _.numberFrom( childPid ) ) );

        // if( process.platform === 'linux' )
        // {
        //   test.is( !_.process.isAlive( _.numberFrom( childPid ) ) )
        //   test.identical( op.exitCode, null );
        //   test.identical( op.ended, true );
        //   test.identical( op.exitSignal, 'SIGTERM' );
        //   test.is( !_.strHas( op.output, 'SIGTERM' ) );
        //   test.is( _.strHas( op.output, 'TerminationBegin' ) );
        // }
        // else if( process.platform === 'win32' )
        // {
        //   test.is( !_.process.isAlive( _.numberFrom( childPid ) ) )
        //   test.identical( op.exitCode, null );
        //   test.identical( op.ended, true );
        //   test.identical( op.exitSignal, 'SIGTERM' );
        //   test.is( !_.strHas( op.output, 'SIGTERM' ) );
        //   test.is( _.strHas( op.output, 'TerminationBegin' ) );
        // }
        // else
        // {
        //   test.is( _.process.isAlive( _.numberFrom( childPid ) ) ) /* qqq for Vova : ?? aaa : remade this test */
        //   test.identical( op.exitCode, null );
        //   test.identical( op.ended, true );
        //   test.identical( op.exitSignal, 'SIGTERM' );
        //   test.is( _.strHas( op.output, 'SIGTERM' ) );
        //   test.is( !_.strHas( op.output, 'TerminationBegin' ) );
        // }

        return _.time.out( context.t1 * 3, () =>
        {
          test.is( !_.process.isAlive( _.numberFrom( childPid ) ) )
          var detachedPID = _.numberFrom( a.fileProvider.fileRead( a.abs( a.routinePath, 'detachedPID' ) ) );
          test.identical( detachedPID, _.numberFrom( childPid ) );
          a.fileProvider.fileDelete( a.abs( a.routinePath, 'detachedPID' ) );
          return null;
        });
      })

      return ready;
    })

    /* */

    .then( () =>
    {
      test.case = `modeParent:${modeParent} modeChild:${modeChild} parent -> detached child, terminate withChildren : 1, detached child should be terminated`
      var o =
      {
        execPath : modeParent === 'fork' ? testAppPath : 'node ' + testAppPath,
        args : [ modeChild ],
        mode : modeParent,
        outputPiping : 1,
        outputCollecting : 1,
        throwingExitCode : 0
      }

      let childPid;
      let ready = _.Consequence();

      _.process.start( o );

      o.process.stdout.on( 'data', ( data ) =>
      {
        data = data.toString();
        if( _.strHas( data, 'ready' ) )
        ready.take( null );
      });

      ready.then( () =>
      {
        childPid = _.numberFrom( a.fileProvider.fileRead( a.abs( a.routinePath, 'childPID' ) ) );
        return _.process.terminate({ pnd : o.process, withChildren : 1 });
      });

      ready.then( () =>
      {
        test.identical( o.conTerminate.resourcesCount(), 1 );

        test.identical( o.exitCode, null );
        test.identical( o.exitSignal, 'SIGTERM' );
        test.identical( o.ended, true );
        test.is( _.strHas( o.output, 'SIGTERM' ) );
        test.is( !_.strHas( o.output, 'TerminationBegin' ) );
        test.is( !_.process.isAlive( _.numberFrom( o.process.pid ) ) );
        test.is( !_.process.isAlive( _.numberFrom( childPid ) ) );

        return _.time.out( context.t1 * 3, () =>
        {
          test.is( !a.fileProvider.fileExists( a.abs( a.routinePath, 'detachedPID' ) ) );
          return null;
        });
      })

      return ready;
    })

    /* - */

    return ready;
  }

  /* - */

  function program1()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    let mode = process.argv[ 2 ];
    var o =
    {
      execPath : mode === 'fork' ? 'program2.js' : 'node program2.js',
      currentPath : __dirname,
      mode,
      stdio : 'ignore',
      detaching : 1,
      inputMirroring : 0,
      outputPiping : 0,
      throwingExitCode : 0
    }

    _.process.start( o );

    o.conStart.thenGive( () =>
    {
      _.fileProvider.fileWrite( _.path.join( __dirname, 'childPID' ), o.process.pid.toString() );
      console.log( 'ready' );
    })

    _.time.out( context.t1, () =>
    {
      console.log( 'TerminationBegin' )
      _.procedure.terminationBegin()
      return null;
    })
  }

  function program2()
  {
    console.log( 'program2::start' )
    setTimeout( () =>
    {
      console.log( 'program2::end' )
      var fs = require( 'fs' );
      var path = require( 'path' )
      fs.writeFileSync( path.join( __dirname, 'detachedPID' ), process.pid.toString() )
    }, context.t1 * 3 );
  }
}

terminateDetachedComplex.timeOut = 150000;

//

function terminateWithChildren( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );
  let testAppPath3 = a.program( testApp3 );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctly with detached processes
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'child -> child, kill first child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid, terminated;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      terminated = _.process.terminate({ pid : o.process.pid, withChildren : 1 });
    })

    ready.then( ( op ) =>
    {
      return terminated.then( () =>
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.identical( _.strCount( op.output, 'SIGTERM' ), 2 );
        test.identical( _.strCount( op.output, 'SIGTERM CHILD' ), 1 );
        test.is( !_.process.isAlive( o.process.pid ) )
        test.is( !_.process.isAlive( lastChildPid ) );
        var file = a.fileProvider.fileRead( a.abs( a.routinePath, lastChildPid.toString() ) );
        test.identical( file, lastChildPid.toString() )
        return null;
      })
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'child -> child, kill last child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let lastChildPid, terminated;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      terminated = _.process.terminate({ pid : lastChildPid, withChildren : 1 });
    })

    ready.then( ( op ) =>
    {
      return terminated.then( () =>
      {
        test.identical( op.exitCode, null ); /* qqq for Vova : test is probably bad. fails on Mint */
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.identical( _.strCount( op.output, 'SIGTERM' ), 1 );
        test.identical( _.strCount( op.output, 'SIGTERM CHILD' ), 1 );
        test.is( !_.process.isAlive( o.process.pid ) )
        test.is( !_.process.isAlive( lastChildPid ) );
        var file = a.fileProvider.fileRead( a.abs( a.routinePath, lastChildPid.toString() ) );
        test.identical( file, lastChildPid.toString() )
        return null;
      })
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'parent -> child*'
    var o =
    {
      execPath : 'node ' + testAppPath3,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, terminated;
    o.process.on( 'message', ( e ) =>
    {
      children = e.map( ( src ) => _.numberFrom( src ) )
      terminated = _.process.terminate({ pid : o.process.pid, withChildren : 1 });
    })

    ready.then( ( op ) =>
    {
      return terminated.then( () =>
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.identical( _.strCount( op.output, 'SIGTERM' ), 3 );
        test.identical( _.strCount( op.output, 'SIGTERM CHILD' ), 2 );
        test.is( !_.process.isAlive( o.process.pid ) )
        test.is( !_.process.isAlive( children[ 0 ] ) );
        test.is( !_.process.isAlive( children[ 1 ] ) );
        var file = a.fileProvider.fileRead( a.abs( a.routinePath, children[ 0 ].toString() ) );
        test.identical( file, children[ 0 ].toString() )
        var file = a.fileProvider.fileRead( a.abs( a.routinePath, children[ 1 ].toString() ) );
        test.identical( file, children[ 1 ].toString() )
        return null;
      })

    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'process is not running';
    var o =
    {
      execPath : 'node ' + testAppPath2,
      mode : 'spawn',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o );
    o.process.kill('SIGKILL');

    return o.ready.then( () =>
    {
      let ready = _.process.terminate({ pid : o.process.pid, withChildren : 1 });
      return test.shouldThrowErrorAsync( ready );
    })

  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    var o =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      stdio : 'inherit',
      outputPiping : 0,
      outputCollecting : 0,
      ipc : 1,
      inputMirroring : 0,
      throwingExitCode : 0
    }
    _.process.start( o );
    o.process.on( 'message', () => process.send( o.process.pid ) )
    setTimeout( () => {}, 5000 )
  }

  function testApp2()
  {
    process.on( 'SIGTERM', () =>
    {
      console.log( 'SIGTERM CHILD' )
      var fs = require( 'fs' );
      var path = require( 'path' )
      fs.writeFileSync( path.join( __dirname, process.pid.toString() ), process.pid.toString() )
      process.exit( 0 );
    })
    if( process.send )
    process.send( process.pid );
    setTimeout( () => {}, 5000 )
  }

  function testApp3()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    let detaching = process.argv[ 2 ] === 'detached';
    let c1 = new _.Consequence();
    let c2 = new _.Consequence();

    var o1 =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      detaching,
      ipc : 1,
      stdio : 'inherit',
      outputCollecting : 0,
      outputPiping : 0,
      inputMirroring : 0,
      throwingExitCode : 0
    }
    _.process.start( o1 );
    o1.process.on( 'message', () => c1.take( o1.process.pid ) )

    var o2 =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      detaching,
      ipc : 1,
      stdio : 'inherit',
      outputCollecting : 0,
      outputPiping : 0,
      inputMirroring : 0,
      throwingExitCode : 0
    }
    _.process.start( o2 );
    o2.process.on( 'message', () => c2.take( o2.process.pid ) )

    _.Consequence.AndKeep( c1, c2 )
    .then( () =>
    {
      process.send([ o1.process.pid, o2.process.pid ]);
      return null;
    })
    setTimeout( () => {}, 5000 )
  }
}

//

function terminateWithDetachedChildren( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );
  let testAppPath3 = a.program( testApp3 );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctly with detached processes
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'parent -> detached'
    var o =
    {
      execPath : 'node ' + testAppPath3 + ' detached',
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, terminated;
    o.process.on( 'message', ( e ) =>
    {
      children = e.map( ( src ) => _.numberFrom( src ) )
      terminated = _.process.terminate({ pid : o.process.pid, withChildren : 1 });
    })

    ready.then( ( op ) =>
    {
      return terminated.then( () =>
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.is( _.strHas( op.output, 'SIGTERM' ) );
        return _.time.out( 9000, () =>
        {
          /* zzz : problem with termination of detached proces on Windows, child process does't receive SIGINT */
          test.is( a.fileProvider.fileExists( a.abs( a.routinePath, children[ 0 ].toString() ) ) )
          test.is( a.fileProvider.fileExists( a.abs( a.routinePath, children[ 1 ].toString() ) ) )
          test.is( !_.process.isAlive( o.process.pid ) )
          test.is( !_.process.isAlive( children[ 0 ] ) );
          test.is( !_.process.isAlive( children[ 1 ] ) );
          return null;
        })
      })
    })

    return ready;
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    var o =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      stdio : 'inherit',
      inputMirroring : 0,
      throwingExitCode : 0
    }
    _.process.start( o );
    _.time.out( 1000, () =>
    {
      process.send( o.process.pid )
    })
  }

  function testApp2()
  {
    process.on( 'SIGTERM', () =>
    {
      console.log( 'SIGTERM' )
      var fs = require( 'fs' );
      var path = require( 'path' )
      fs.writeFileSync( path.join( __dirname, process.pid.toString() ), process.pid.toString() )
      process.exit( 0 );
    })
    if( process.send )
    process.send( process.pid );
    setTimeout( () => {}, 5000 )
  }

  function testApp3()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    let detaching = process.argv[ 2 ] === 'detached';
    var o1 =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      detaching : 1,
      stdio : 'ignore',
      outputPiping : 0,
      inputMirroring : 0,
      outputCollecting : 0,
      throwingExitCode : 0
    }
    _.process.start( o1 );
    o1.conTerminate.catch( ( err ) =>
    {
      _.errAttend( err )
      return null;
    })
    var o2 =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      detaching : 1,
      stdio : 'ignore',
      outputPiping : 0,
      inputMirroring : 0,
      outputCollecting : 0,
      throwingExitCode : 0
    }
    _.process.start( o2 );
    o2.conTerminate.catch( ( err ) =>
    {
      _.errAttend( err )
      return null;
    })
    _.time.out( 1000, () =>
    {
      process.send( [ o1.process.pid, o2.process.pid ] )
    })
    _.time.out( 4000, () =>
    {
      _.procedure.terminationBegin();
    })

  }

}

//

function terminateTimeOut( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctly on node14
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  a.ready

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process, timeOut : 1000, withChildren : 0 });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGKILL' );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /*  */

  .then( () =>
  {
    var o =
    {
      execPath :  testAppPath,
      mode : 'fork',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.on( 'message', () =>
    {
      _.process.terminate({ pnd : o.process, timeOut : 1000, withChildren : 0 });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, null );
      test.identical( op.ended, true );
      test.identical( op.exitSignal, 'SIGKILL' );
      test.is( _.strHas( op.output, 'SIGTERM' ) );
      test.is( !_.strHas( op.output, 'Application timeout!' ) );
      return null;
    })

    return ready;
  })

  /*  */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'shell',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    o.process.stdout.on( 'data', ( data ) =>
    {
      data = data.toString();
      if( _.strHas( data, 'ready' ))
      _.process.terminate({ pnd : o.process });
    })

    ready.then( ( op ) =>
    {
      if( process.platform === 'linux' )
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGTERM' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }
      else if( process.platform === 'darwin' )
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGKILL' );
        test.is( _.strHas( op.output, 'SIGTERM' ) );
        test.is( !_.strHas( op.output, 'Application timeout!' ) );
      }
      else
      {
        test.identical( op.exitCode, null );
        test.identical( op.ended, true );
        test.identical( op.exitSignal, 'SIGKILL' );
        test.is( !_.strHas( op.output, 'SIGTERM' ) );
        test.is( _.strHas( op.output, 'Application timeout!' ) );
      }

      return null;
    })

    return ready;
  })

  /* - */

  return a.ready;

  /* - */

  function testApp()
  {
    process.on( 'SIGTERM', () =>
    {
      console.log( 'SIGTERM' )
    })
    if( process.send )
    process.send( process.pid );
    else
    console.log( 'ready' );
    setTimeout( () =>
    {
      console.log( 'Application timeout!' )
    }, 10000 )
  }
}

//

function terminateDifferentStdio( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );

  // if( process.platform === 'win32' )
  // {
  //   // qqq for Vova : windows-kill doesn't work correctly on node14
  //   // investigate if its possible to use process.kill instead of windows-kill
  //   test.identical( 1, 1 )
  //   return;
  // }

  /* */

  a.ready

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'inherit',
      outputPiping : 0,
      outputCollecting : 0,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1500, () =>
    {
      return test.mustNotThrowError( () => _.process.terminate( o.process.pid ) )
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( a.fileProvider.fileExists( a.abs( a.routinePath, o.process.pid.toString() ) ) );
      return null;
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'ignore',
      outputPiping : 0,
      outputCollecting : 0,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1500, () =>
    {
      return test.mustNotThrowError( () => _.process.terminate( o.process.pid ) )
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( a.fileProvider.fileExists( a.abs( a.routinePath, o.process.pid.toString() ) ) );
      return null;
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'pipe',
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1500, () =>
    {
      return test.mustNotThrowError( () => _.process.terminate( o.process.pid ) )
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( a.fileProvider.fileExists( a.abs( a.routinePath, o.process.pid.toString() ) ) );
      return null;
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'pipe',
      ipc : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1500, () =>
    {
      return test.mustNotThrowError( () => _.process.terminate( o.process.pid ) )
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( a.fileProvider.fileExists( a.abs( a.routinePath, o.process.pid.toString() ) ) );
      return null;
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'inherit',
      outputPiping : 0,
      outputCollecting : 0,
      ipc : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1500, () =>
    {
      return test.mustNotThrowError( () => _.process.terminate( o.process.pid ) )
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( a.fileProvider.fileExists( a.abs( a.routinePath, o.process.pid.toString() ) ) );
      return null;
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      stdio : 'ignore',
      outputPiping : 0,
      outputCollecting : 0,
      ipc : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o )

    _.time.out( 1500, () =>
    {
      return test.mustNotThrowError( () => _.process.terminate( o.process.pid ) )
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.is( a.fileProvider.fileExists( a.abs( a.routinePath, o.process.pid.toString() ) ) );
      return null;
    })

    return ready;
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    process.on( 'SIGTERM', () =>
    {
      var fs = require( 'fs' );
      var path = require( 'path' )
      fs.writeFileSync( path.join( __dirname, process.pid.toString() ), process.pid.toString() );
      process.exit( 0 );
    })
    setTimeout( () =>
    {
      process.exit( -1 );
    }, 5000 )
  }
}

//

/* zzz for Vova : extend, cover kill of group of processes */

function killComplex( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'Kill child of child process'
    var o =
    {
      execPath :  'node ' + testAppPath2,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );

    let pid = null;
    let childOfChild = null;
    o.process.on( 'message', ( e ) =>
    {
      if( !pid )
      {
        pid = _.numberFrom( e )
        _.process.kill( pid );
      }
      else
      {
        childOfChild = e;
      }
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      test.identical( childOfChild.pid, pid );
      if( process.platform === 'win32' )
      {
        test.identical( childOfChild.exitCode, 1 );
        test.identical( childOfChild.exitSignal, null );
      }
      else
      {
        test.identical( childOfChild.exitCode, null );
        test.identical( childOfChild.exitSignal, 'SIGKILL' );
      }

      return null;
    })

    return ready;
  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    setTimeout( () =>
    {
      console.log( 'Application timeout!' )
    }, 2500 )
  }

  function testApp2()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    var testAppPath = _.fileProvider.path.nativize( _.path.join( __dirname, 'testApp.js' ) );
    var o = { execPath : 'node ' + testAppPath, throwingExitCode : 0  }
    var ready = _.process.start( o )
    process.send( o.process.pid );
    ready.then( ( op ) =>
    {
      process.send({ exitCode : o.exitCode, pid : o.process.pid, exitSignal : o.exitSignal })
      return null;
    })
    return ready;
  }

}

//

function children( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'parent -> child -> child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, lastChildPid;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      children = _.process.children({ pid : process.pid, format : 'tree' });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      var expected =
      {
        [ process.pid ] :
        {
          [ o.process.pid ] :
          {
            [ lastChildPid ] : {}
          }
        }
      }
      return children.then( ( op ) =>
      {
        test.contains( op, expected );
        return null;
      })
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'parent -> child -> child, search from fist child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, lastChildPid;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e )
      children = _.process.children({ pid : o.process.pid, format : 'tree' });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      var expected =
      {
        [ o.process.pid ] :
        {
          [ lastChildPid ] : {}
        }
      }
      return children.then( ( op ) =>
      {
        test.contains( op, expected );
        return null;
      })
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'parent -> child -> child, start from last child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, lastChildPid;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e )
      children = _.process.children({ pid : lastChildPid, format : 'tree' });
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      var expected =
      {
        [ lastChildPid ] : {}
      }
      return children.then( ( op ) =>
      {
        test.contains( op, expected );
        return null;
      })

    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'parent -> child*'
    var o =
    {
      execPath : 'node ' + testAppPath2,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let o1 = _.mapExtend( null, o );
    let o2 = _.mapExtend( null, o );

    let r1 = _.process.start( o1 );
    let r2 = _.process.start( o2 );
    let children;

    let ready = _.Consequence.AndTake( r1, r2 );

    o1.process.on( 'message', () =>
    {
      children = _.process.children({ pid : process.pid, format : 'tree' });
    })

    ready.then( ( op ) =>
    {
      test.identical( op[ 0 ].exitCode, 0 );
      test.identical( op[ 0 ].exitSignal, null );
      test.identical( op[ 0 ].exitReason, 'normal' );
      test.identical( op[ 0 ].ended, true );
      test.identical( op[ 0 ].state, 'terminated' );

      test.identical( op[ 1 ].exitCode, 0 );
      test.identical( op[ 1 ].exitSignal, null );
      test.identical( op[ 1 ].exitReason, 'normal' );
      test.identical( op[ 1 ].ended, true );
      test.identical( op[ 1 ].state, 'terminated' );
      var expected =
      {
        [ process.pid ] :
        {
          [ op[ 0 ].process.pid ] : {},
          [ op[ 1 ].process.pid ] : {},
        }
      }
      return children.then( ( op ) =>
      {
        test.contains( op, expected );
        return null;
      })
    })

    return ready;
  })

  /* - */

  .then( () =>
  {
    test.case = 'only parent'
    return _.process.children({ pid : process.pid, format : 'tree' })
    // return _.process.children( process.pid )
    .then( ( op ) =>
    {
      test.contains( op, { [ process.pid ] : {} })
      return null;
    })
  })

  /* - */

  .then( () =>
  {
    test.case = 'process is not running';
    var o =
    {
      execPath : 'node ' + testAppPath2,
      mode : 'spawn',
      outputCollecting : 1,
      throwingExitCode : 0
    }

    _.process.start( o );
    o.process.kill('SIGKILL');

    return o.ready.then( () =>
    {
      // let ready = _.process.children( o.process.pid );
      let ready = _.process.children({ pid : o.process.pid, format : 'tree' });
      return test.shouldThrowErrorAsync( ready );
    })

  })

  /* */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    var o =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      inputMirroring : 0
    }
    _.process.start( o );
    process.send( o.process.pid )
  }

  function testApp2()
  {
    if( process.send )
    process.send( process.pid );
    setTimeout( () => {}, 1500 )
  }
}

//

function childrenOptionFormatList( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );

  /* */

  a.ready

  .then( () =>
  {
    test.case = 'parent -> child -> child'
    var o =
    {
      execPath :  'node ' + testAppPath,
      mode : 'spawn',
      ipc : 1,
      outputCollecting : 1,
      throwingExitCode : 0
    }

    let ready = _.process.start( o );
    let children, lastChildPid;

    o.process.on( 'message', ( e ) =>
    {
      lastChildPid = _.numberFrom( e );
      children = _.process.children({ pid : process.pid, format : 'list' })
    })

    ready.then( ( op ) =>
    {
      test.identical( op.exitCode, 0 );
      test.identical( op.exitSignal, null );
      test.identical( op.exitReason, 'normal' );
      test.identical( op.ended, true );
      test.identical( op.state, 'terminated' );
      return children.then( ( op ) =>
      {
        if( process.platform === 'win32' )
        {
          test.identical( op.length, 5 );

          test.identical( op[ 0 ].pid, process.pid );
          test.identical( op[ 1 ].pid, o.process.pid );

          test.is( _.numberIs( op[ 2 ].pid ) );
          test.identical( op[ 2 ].name, 'conhost.exe' );

          test.identical( op[ 3 ].pid, lastChildPid );

          test.is( _.numberIs( op[ 4 ].pid ) );
          test.identical( op[ 4 ].name, 'conhost.exe' );

        }
        else
        {
          var expected =
          [
            { pid : process.pid },
            { pid : o.process.pid },
            { pid : lastChildPid }
          ]
          test.contains( op, expected );
        }
        return null;
      })
    })

    return ready;
  })

  /*  */

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );
    var o =
    {
      execPath : 'node testApp2.js',
      currentPath : __dirname,
      mode : 'spawn',
      inputMirroring : 0
    }
    _.process.start( o );
    process.send( o.process.pid )
  }

  function testApp2()
  {
    if( process.send )
    process.send( process.pid );
    setTimeout( () => {}, 1500 )
  }
}

// --
// experiment
// --

function experiment( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.program( testApp );
  let testAppPath2 = a.program( testApp2 );
  let o3 =
  {
    outputPiping : 1,
    outputCollecting : 1,
    applyingExitCode : 0,
    throwingExitCode : 1
  }

  let o2;

  /* - */

  a.ready.then( function()
  {
    test.case = 'mode : shell, passingThrough : true, no args';

    o =
    {
      execPath :  'node testApp.js *',
      currentPath : a.routinePath,
      mode : 'spawn',
      stdio : 'pipe'
    }

    return null;
  })
  .then( function( arg )
  {
    var options = _.mapSupplement( {}, o2, o3 );

    return _.process.start( options )
    .then( function()
    {
      test.identical( options.exitCode, 0 );
      test.identical( options.exitSignal, null );
      test.identical( options.exitReason, 'normal' );
      test.identical( options.ended, true );
      test.identical( options.state, 'terminated' );
      test.is( _.strHas( options.output, `[ '*' ]` ) );
      return null;
    })
  })

  return a.ready;

  /* - */

  function testApp()
  {
    let _ = require( toolsPath );
    _.include( 'wProcess' );
    _.include( 'wFiles' );

    _.process.start
    ({
      execPath : 'node testApp2.js',
      mode : 'shell',
      passingThrough : 1,
      stdio : 'inherit',
      outputPiping : 0,
      outputCollecting : 0,
      inputMirroring : 0
    })
  }

  function testApp2()
  {
    console.log( process.argv.slice( 2 ) );
  }
}

experiment.experimental = 1;

//

function experiment2( test )
{
  let context = this;
  let a = context.assetFor( test, false );
  let testAppPath = a.path.nativize( a.program( testApp ) );
  let track;

  var o =
  {
    execPath : 'node -e "console.log(process.ppid,process.pid)"',
    mode : 'shell',
    stdio : 'pipe'
  }
  _.process.start( o );
  console.log( 'Shell:', o.process.pid )

}

experiment2.experimental = 1;

//

function experiment3( test )
{
  let context = this;
  let a = context.assetFor( test, false );

  var o =
  {
    execPath : 'node -e "console.log(setTimeout(()=>{},10000))"',
    mode : 'spawn',
    stdio : 'pipe',
    timeOut : 2000,
    throwingExitCode : 0
  }
  _.process.start( o );

  o.conTerminate.then( ( op ) =>
  {
    test.identical( op.ended, true );
    test.identical( op.exitReason, 'signal' );
    test.identical( op.exitCode, null );
    test.identical( op.exitSignal, 'SIGTERM' );
    test.is( !_.process.isAlive( op.process.pid ) );
    return null;
  })

  return o.conTerminate;
}

experiment3.experimental = 1;
experiment3.description =
`
Shows that timeOut kills the child process and handleClose is called
`

//

//

function experimentIpcDeasync( test )
{
  let context = this;
  let a = context.assetFor( test, false );

  for( let i = 0 ; i < 10; i++ )
  a.ready.then( run )

  return a.ready;

  function run( )
  {
    var o =
    {
      execPath : 'node -e "process.send(1);setTimeout(()=>{},500)"',
      mode : 'spawn',
      stdio : 'pipe',
      ipc : 1,
      throwingExitCode : 0
    }
    _.process.start( o );

    var ready = _.Consequence();

    o.process.on( 'message', () =>
    {
      let interval = setInterval( () =>
      {
        if( _.process.isAlive( o.process.pid ) )
        return false;
        ready.take( true );
        clearInterval( interval );
      })
      ready.deasync();
    })


    return _.Consequence.AndKeep( o.conTerminate, ready );
  }
}

experimentIpcDeasync.experimental = 1;
experimentIpcDeasync.description =
`
This expriment shows problem with usage of _.time.periodic with deasync.
Problem happens only if code if deasync is launched from 'message' callback
`

// --
// suite
// --

var Proto =
{

  name : 'Tools.l4.ProcessBasic',
  silencing : 1,
  routineTimeOut : 60000,
  onSuiteBegin : suiteBegin,
  onSuiteEnd : suiteEnd,

  context :
  {

    assetFor,
    suiteTempPath : null,

    t0 : 100,
    t1 : 1000,
    t2 : 5000,
    t3 : 15000,

  },

  tests :
  {

    // basic

    startBasic,
    startBasic2,
    startFork,
    startErrorHandling,
    // startSingleOptionDry,

    // sync

    startSync,
    startSyncDeasync,
    startSpawnSyncDeasync,
    startSpawnSyncDeasyncThrowing,
    startShellSyncDeasync,
    startShellSyncDeasyncThrowing,
    startForkSyncDeasync,
    startForkSyncDeasyncThrowing,
    startMultipleSyncDeasync,

    // arguments

    startWithoutExecPath,
    startArgsOption,
    startArgumentsParsing,
    startArgumentsParsingNonTrivial,
    startArgumentsNestedQuotes,
    startExecPathQuotesClosing,
    startExecPathSeveralCommands,
    startExecPathNonTrivialModeShell,
    startArgumentsHandlingTrivial,
    startArgumentsHandling,
    startImportantExecPath,
    startImportantExecPathPassingThrough,
    startNormalizedExecPath,
    startExecPathWithSpace,
    startNjsPassingThroughExecPathWithSpace,
    startPassingThroughExecPathWithSpace,

    // procedures / chronology / structural

    startProcedureTrivial,
    startProcedureExists,
    startProcedureStack,
    startProcedureStackMultiple, /* qqq for Yevhen : extend it using startProcedureStack as example */
    startOnTerminateSeveralCallbacksChronology,
    startChronology,

    // delay

    startReadyDelay,
    startReadyDelayMultiple,
    startOptionWhenDelay,
    startOptionWhenTime,
    // startOptionTimeOut, /* qqq for Vova : fix please */
    // startAfterDeath, /* zzz : fix */
    // startAfterDeathOutput, /* zzz : ? */

    // detaching

    startDetachingModeSpawnResourceReady,
    startDetachingModeForkResourceReady,
    startDetachingModeShellResourceReady,
    startDetachingModeSpawnNoTerminationBegin,
    startDetachingModeForkNoTerminationBegin,
    startDetachingModeShellNoTerminationBegin,
    startDetachedOutputStdioIgnore,
    startDetachedOutputStdioPipe,
    startDetachedOutputStdioInherit,
    startDetachingModeSpawnIpc,
    startDetachingModeForkIpc,
    startDetachingModeShellIpc,

    startDetachingTrivial,
    startDetachingChildExitsAfterParent,
    startDetachingChildExitsBeforeParent,
    startDetachingDisconnectedEarly,
    startDetachingDisconnectedLate,
    startDetachingChildExistsBeforeParentWaitForTermination,
    startDetachingEndCompetitorIsExecuted,
    startDetachingTerminationBegin,
    startEventClose,
    startEventExit,
    startDetachingThrowing,
    startNjsDetachingChildThrowing,

    // on

    startOnStart,
    startOnTerminate,
    startNoEndBug1,
    startWithDelayOnReady,
    startOnIsNotConsequence,

    // concurrent

    startConcurrent,
    shellerConcurrent,

    // helper

    startNjs,
    startNjsWithReadyDelayStructural,

    // sheller

    sheller,
    shellerArgs,
    shellerFields,

    // output

    startOptionOutputCollecting,
    startOptionOutputGraying,
    startOptionLogger,
    startOptionLoggerTransofrmation,
    startOutputOptionsCompatibilityLateCheck,
    startOptionVerbosity,

    // etc

    appTempApplication,
    startDiffPid,

    // other options

    startOptionDryRun,
    startOptionCurrentPath,
    startOptionCurrentPaths,
    startOptionPassingThrough, /* qqq for Yevhen : extend please | aaa : Done. Yevhen S. */

    // termination

    exitReason,
    exitCode,

    pidFrom,
    isAlive,
    statusOf,

    kill,
    killSync, /* qqq for Vova : does not work! */
    killOptionWithChildren,
    terminate,
    terminateSync,
    startErrorAfterTerminationWithSend,
    startTerminateHangedWithExitHandler,
    startTerminateAfterLoopRelease,

    endSignalsBasic,
    endSignalsOnExit,
    endSignalsOnExitExit,

    terminateComplex,
    terminateDetachedComplex,
    terminateWithChildren,
    terminateWithDetachedChildren, // zzz for Vova:investigate and fix termination of deatched process on Windows
    terminateTimeOut, /* xxx qqq for Vova : make it working */
    terminateDifferentStdio,
    killComplex,

    // children

    children,
    childrenOptionFormatList,

    // experiments

    experiment,
    experiment2,
    experiment3,
    experimentIpcDeasync, /* xxx : investigate */

  }

}

_.mapExtend( Self, Proto );

//

Self = wTestSuite( Self );
if( typeof module !== 'undefined' && !module.parent )
wTester.test( Self )

})();
