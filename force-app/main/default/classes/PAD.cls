/*
----------------------------------------------------------------------
-- - Name          : PAD
-- - Author        : ECO
-- - Description   : Allow user to skip triggers
-- - Module        : CRM Radiall
----------------------------------------------------------------------
*/
public class PAD {
    public static final String BypassTrigger;
    private static final Set<String> requiredOnce = new Set<String>{};//List of Apex codes that should run only once. Add any code to the list
    public static Set<String> hasRun = new Set<String>();//List of Apex code that has already been run. Keep this list empty.

    static{
        System.Debug('## >>> PAD constructor :BEGIN <<< run by ' + UserInfo.getName());
        User user = [SELECT ByPass_Trigger__c FROM User WHERE Id =:UserInfo.getUserId() LIMIT 1];
        BypassTrigger = ';' + user.ByPass_Trigger__c + ';';
        System.Debug('## >>> BypassTrigger: '+BypassTrigger);
        System.Debug('## >>> PAD constructor : END <<<');
    }

    public static boolean canTrigger(String ApexName){ //If no bypass
        if(requiredOnce.contains(ApexName)){//If it should run Once
            if(hasRun.contains(ApexName)) return false;//Already run, should not run
            hasRun.add(ApexName);//Never run, can run only if not bypassed
        }
        return(BypassTrigger.indexOf(';'+ApexName+';')==-1);
    }
}