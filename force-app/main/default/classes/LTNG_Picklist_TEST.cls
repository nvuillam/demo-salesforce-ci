@isTest
private class LTNG_Picklist_TEST {

    private static testMethod void testLTNG_Picklist() {
        
        Test.startTest();
        
        LTNG_Picklist.getPicklistConfig('TimeSheet__c', 'Phase__c');
        LTNG_Picklist.getPicklistConfig('TimeSheet__c', 'SousPhase__c');
        
        Test.stopTest();
    }
}