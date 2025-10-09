@isTest(isParallel=true)
private with sharing class TestClass1Test {
    
    @isTest static void testX(){
        TestClass1.someMethod();
    }

}