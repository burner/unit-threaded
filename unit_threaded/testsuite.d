module unit_threaded.testsuite;

import unit_threaded.testcase;
import unit_threaded.writer_thread;
import std.datetime;
import std.parallelism;
import std.concurrency;

/**
 * Responsible for running tests
 */
struct TestSuite {
    this(TestCase[] tests) {
        _tests = tests;
    }

    double run(bool multiThreaded = true) {
        _stopWatch.start();

        auto tid = spawn(&writeInThread);
        if(multiThreaded) {
            foreach(test; taskPool.parallel(_tests)) innerLoop(test, tid);
        } else {
            foreach(test; _tests) innerLoop(test, tid);
        }

        tid.send(thisTid); //tell it to join
        receiveOnly!Tid(); //wait for it to join

        import std.stdio;
        if(_failures) writeln("\n");
        foreach(failure; _failures) {
            writeln("Test ", failure, " failed.");
        }
        if(_failures) writeln("");

        _stopWatch.stop();
        return _stopWatch.peek().seconds();
    }

    @property ulong numTestsRun() const pure nothrow {
        return _tests.length;
    }

    @property ulong numFailures() const pure nothrow {
        return _failures.length;
    }

    @property bool passed() const pure nothrow {
        return numFailures() == 0;
    }

private:
    TestCase[] _tests;
    string[] _failures;
    StopWatch _stopWatch;

    void addFailure(string testPath) nothrow {
        _failures ~= testPath;
    }

    void innerLoop(TestCase test, Tid writerTid) {
        immutable result = test();
        if(result.failed) {
            addFailure(test.getPath());
        }
        writerTid.send(result.output);
    }
}
