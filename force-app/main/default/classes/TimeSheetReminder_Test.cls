/**
 * Created by Didier Huguet on 20/11/2018.
 */

@IsTest
private class TimeSheetReminder_Test {
    @IsTest
    public static void TimeSheetReminder() {

        Test.StartTest();
        TimeSheetReminder sh = new TimeSheetReminder();
        String sch = '0 0 23 * * ?';
        system.schedule('Test TimeSheetReminder', sch, sh);
        Test.stopTest();

    }
}