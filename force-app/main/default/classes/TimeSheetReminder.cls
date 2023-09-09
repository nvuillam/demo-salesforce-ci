/**
 * Created by Didier Huguet on 20/11/2018.
 */

global class TimeSheetReminder implements Schedulable {

    //public List<String> INVOLVED_PROFILES = new List<String>{'System Administrator', 'Developer', 'Administrateur système', 'Consultant - Force.com'};


    global void execute(SchedulableContext SC) {

        List<User> involvedUsers = [SELECT Id FROM User WHERE IsActive = true AND RecevoirRappelTimesheet__c = true ];

        List<AggregateResult> aggr = [SELECT SUM(Duration__c) duration, Date__c, User__c FROM TimeSheet__c WHERE User__c IN :involvedUsers AND Date__c >= :system.today().toStartOfWeek() AND Date__c <= :system.today() GROUP BY ROLLUP(User__c, Date__c)];



        List<Messaging.SingleEmailMessage > emails = new List<Messaging.SingleEmailMessage >();
        Messaging.SingleEmailMessage tempEmail;
        String htmlBody;
        Boolean timeSheetExist;

        for(User u : involvedUsers){


            tempEmail = new Messaging.SingleEmailMessage();

            tempEmail.setSubject('Rappel TimeSheets');
            tempEmail.setTargetObjectId(u.Id);
            tempEmail.setUseSignature(false);
            tempEmail.setSaveAsActivity(false);

            htmlBody = '<div style="font-family: Arial;"> C\'est bientôt le weekend :),<br /> le moment de faire une petite vérification de tes TimeSheets de la semaine: <br /><br /><table style="font-family: Arial; background-color:#29a2d9; color:white;text-align: center;" cellpadding="3" cellspacing="3"><tr>';

            for(Integer i = 0; i < 5; i++){

                htmlBody += '<th>' +  ((DateTime) system.today().toStartOfWeek().addDays(i)).format('E dd') + '</th>';
            }

            htmlBody += '</tr><tr>';

            for(Integer i = 0; i < 5; i++){
                timeSheetExist = false;
                for(AggregateResult agg : aggr){
                    if(agg.get('User__c') == u.Id && agg.get('Date__c') == system.today().toStartOfWeek().addDays(i)){
                        htmlBody += '<td style="background-color: ' + (agg.get('duration') == 1 ? '#5cb85c': '#f0ad4e') + ';">' + agg.get('duration') + '</td>';
                        timeSheetExist = true;
                        break;
                    }
                }
                if(!timeSheetExist)
                    htmlBody += '<td style="background-color: #d9534f;">0</td>';
            }

            htmlBody += '</tr></table><br /><br />Si besoin, pour les modifier c\'est par <a href="https://hardis-group.my.salesforce.com/" style="color: #29a2d9;">ici</a></div>';

            tempEmail.setHtmlBody(htmlBody);

            emails.add(tempEmail);


        }


        Messaging.sendEmail(emails, false);

    }


}