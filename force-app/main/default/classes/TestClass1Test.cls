@isTest(isParallel=true)
private with sharing class TestClass1Test {
    
    @isTest static void test1(){
        TestClass1.someMethod();
    }

}