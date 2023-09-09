public class LTNG01_TimeSheetQuickCreate {

    public LTNG01_TimeSheetQuickCreate() {}

    @AuraEnabled
    public static InitParams getInitParams(String endDate) {
        return new InitParams(date.valueOf(endDate));
    }

    public class InitParams {

        @AuraEnabled public List<Date> last5days = new List<Date>();
        @AuraEnabled public Map<String, String> dayNamesByDates = new Map<String, String>();
        @AuraEnabled public Map<String, Decimal> durationsByDates = new Map<String, Decimal>();
        @AuraEnabled public List<PicklistItem> projectItems = new List<PicklistItem>();
        @AuraEnabled public Map< String, List<ProjectLineTupple> > projectToLines;
        @AuraEnabled public Map<Id, Project__c> projectIdToProject = new Map<Id, Project__c>();
        @AuraEnabled public ID defaultProjectId;
        @AuraEnabled public String projectIdsWithMandatoryDescriptionJSON;
        @AuraEnabled public String URLbase = System.URL.getSalesforceBaseUrl().toExternalForm();
        @AuraEnabled public Id reportId;
        @AuraEnabled public TimeSheet__c ts;
        @AuraEnabled public String currentUser = UserInfo.getFirstName() + ' ' + UserInfo.getLastName();

        public InitParams(Date endDate) {
            if (endDate == null)
                endDate = date.today();

            this.projectToLines = new map<String, List<ProjectLineTupple>>();
            this.ts = new TimeSheet__c();
            List<Report> reports = [SELECT Id FROM Report WHERE DeveloperName = 'TimeSheet_of_the_week'];
            if(reports.size() > 0) {
                this.reportId = reports[0].Id;
            }

            Date tempDate = endDate;
            while (last5days.size() < 5) {
                if (Integer.valueOf(((DateTime) tempDate).format('u')) < 6) {
                    this.last5days.add(tempDate);
                    this.dayNamesByDates.put(
                        DateTime.newInstance(
                            tempDate.year(), tempDate.month(), tempDate.day()).format('yyyy-MM-dd')
                            , '   ' + ((DateTime) tempDate).format('E dd') + '   '
                        );
                }
                tempDate = tempDate.addDays(-1);
            }
            system.debug(this.dayNamesByDates);
            system.debug(this.last5days);

            this.last5days.sort();

            for (Date d : this.last5days) {
                this.durationsByDates.put(DateTime.newInstance(d.year(), d.month(), d.day()).format('yyyy-MM-dd'), 0);
            }

            for (AggregateResult aggr : [SELECT Date__c, SUM(Duration__c) totalTime
                                        FROM TimeSheet__c
                                        WHERE User__c =: UserInfo.getUserId()
                                        AND Date__c IN: this.last5days
                                        GROUP BY Date__c]) {
                System.debug(LoggingLevel.INFO, 'aggr ' + JSON.serialize(aggr));
                this.durationsByDates.put(
                    DateTime.newInstance(
                        ((Date) aggr.get('Date__c')).year(),
                        ((Date) aggr.get('Date__c')).month(),
                        ((Date) aggr.get('Date__c')).day()
                    ).format('yyyy-MM-dd'),
                    (Decimal) aggr.get('totalTime')
                );
            }

            String account;
            List < String > accountNames = new List < String > ();
            List < Project__c > addedProjects = new List < Project__c > ();
            Map < Id, ProjectMember__c > emptyProjectMembers = new map < Id, ProjectMember__c > ();
            Set < ID > projectIdsWithMandatoryDescription = new Set < ID > ();
            Boolean isDefault = true;

            for (Project__c p : [SELECT Id, Account__r.Name, Name, RequireTimeSheetDescription__c, ImputationQuartTemps__c,
                                    (SELECT Id, User__c from ProjectMembers__r
                                    WHERE user__c =: UserInfo.getUserId() AND projectLine__c = null LIMIT 1)
                                FROM Project__c
                                WHERE IsActive__c = true
                                AND Id IN (SELECT Project__c FROM ProjectMember__c
                                            WHERE User__c =: UserInfo.getUserId() AND ProjectLine__r.Active__c = true)
                                ORDER BY Account__r.Name, Name]) {
                if (!accountNames.contains(p.Account__r.Name)) {
                    accountNames.add(p.Account__r.Name);
                    projectItems.add(new PicklistItem('', p.Account__r.Name, true));
                }
                if (!p.projectMembers__r.isEmpty())
                    emptyProjectMembers.put(p.id, p.projectMembers__r.get(0));
                projectItems.add(new PicklistItem(String.valueOf(p.Id), '    ' + p.Name, false));
                addedProjects.add(p);
                if (isDefault) {
                    defaultProjectId = p.Id;
                    isDefault = false;
                }
                if (p.RequireTimeSheetDescription__c) {
                    projectIdsWithMandatoryDescription.add(p.Id);
                }
                projectIdToProject.put(p.Id, p);
            }

            //R2cupération de la derniere timesheet
            TimeSheet__c[] t = [SELECT id, project__c from timesheet__c where createdById =: userInfo.getUserId() order by CreatedDate DESC LIMIT 1];
            if (!t.isEmpty()) {
                defaultProjectId = t.get(0).Project__c;
            }

            system.debug(projectItems);
            projectIdsWithMandatoryDescriptionJSON = JSON.serialize(projectIdsWithMandatoryDescription);


            for (ProjectLine__c pl : [SELECT id, Name, project__c, NumeroDeLigne__c, revisedQuantity__c, soldQuantity__c,
                                            type__c, workedQuantity__c, (SELECT Id, User__c FROM LineMembers__r)
                                    FROM ProjectLine__c
                                    WHERE Project__c IN: addedProjects
                                    AND Active__c = true
                                    Order By NumeroDeLigne__c]) {
                if (pl.LineMembers__r.isEmpty() && emptyProjectMembers.containsKey(pl.project__c)) {
                    this.addLineToMap(pl, emptyProjectMembers.get(pl.project__c));
                } else {
                    for (ProjectMember__c pm: pl.LineMembers__r) {
                        if (pm.User__c == userInfo.getUserId()) {
                            this.addLineToMap(pl, pm);
                            break;
                        }
                    }
                }
            }
        }

        private void addLineToMap(projectLine__c pl, projectMember__c pm) {
            if (!this.projectToLines.containsKey(pl.project__c)) {
                this.projectToLines.put(pl.project__c, new ProjectLineTupple[] {});
            }
            this.projectToLines.get(pl.project__c).add(new ProjectLineTupple(pl, pm));
        }
    }

    @AuraEnabled
    public static Boolean saveTS(Decimal duration, String typeTS, String selectedDate, String description, ID projectId, Id projectLine, Id projectMember, TimeSheet__c tsForPhase) {
        System.debug(duration);
        System.debug(typeTS);
        System.debug(selectedDate);
        System.debug(date.valueOf(selectedDate));
        System.debug(description);
        System.debug(projectId);
        System.debug(tsForPhase);

        TimeSheet__c TS = new TimeSheet__c(
            Date__c = date.valueOf(selectedDate),
            Duration__c = duration,
            Type__c = typeTS,
            User__c = UserInfo.getUserId(),
            Description__c = description,
            Project__c = projectId,
            Phase__c = tsForPhase.Phase__c,
            ProjectLine__c = projectLine,
            ProjectMember__c = projectMember,
            SousPhase__c = tsForPhase.SousPhase__c
        );
        System.debug(TS);
        //S'il existe une TS pour le même jour, même projet, même type et même user, alors on ne créé pas une nouvelle TS mais on modifie la durée de la première
        List < TimeSheet__c > dupeTimeSheet = [
            SELECT Id, Phase__c, SousPhase__c, Duration__c, Description__c, Project__r.MergeTimesheet__c
            FROM TimeSheet__c WHERE User__c =: UserInfo.getUserId() AND Date__c =: date.valueOf(selectedDate)
            AND Project__c =: (String) projectId AND ProjectLine__c = :(String) projectLine AND Type__c = :typeTS LIMIT 1
        ];

        System.debug(LoggingLevel.WARN, 'after return ');
        //TPR ASDSBHRI-51 : Prevent merge if the project field MergeTimesheet__c is false
        if (!dupeTimeSheet.isEmpty() && dupeTimeSheet[0].Project__r.MergeTimesheet__c &&
            dupeTimeSheet[0].Phase__c == null && dupeTimeSheet[0].SousPhase__c == null &&
            tsForPhase.Phase__c == null && tsForPhase.SousPhase__c ==
            null // cas particulier des phases + sous-phase ou on "accepte" de créer des lignes différentes. Faut-il vraiment garder ce système de dédoublonnage ??
        ) {
            dupeTimeSheet[0].Duration__c += duration;

            if (String.isNotBlank(description))
                dupeTimeSheet[0].Description__c = (String.isBlank(dupeTimeSheet[0].Description__c) ? '' : dupeTimeSheet[0].Description__c + '\n') + description;

            update dupeTimeSheet[0];
        } else {
            insert TS;
        }

        return true;
    }

    public class PicklistItem {

        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean disabled;

        public PicklistItem(String value, String label, Boolean disabled) {
            this.value = value;
            this.label = label;
            this.disabled = disabled;
        }
    }

    public class projectLineTupple {
        @AuraEnabled public Id lineId {get;set;}
        @AuraEnabled public String lineName {get;set;}
        @AuraEnabled public String lineType {get;set;}
        @AuraEnabled public Id pmId {get;set;}
        @AuraEnabled public decimal totalQuantity {get;set;}
        @AuraEnabled public decimal workedQuantity {get;set;}
        public projectLineTupple(ProjectLine__c pl, ProjectMember__c pm) {
            this.lineId = pl.id;
            this.lineName = pl.Name;
            this.pmId = pm.id;
            this.totalQuantity = pl.Type__c == 'Forfait' ?
                (pl.RevisedQuantity__c == null ? pl.SoldQuantity__c : pl.RevisedQuantity__c)
                    : (pl.RevisedQuantity__c == null ? 0 : pl.RevisedQuantity__c);
            this.workedQuantity = pl.WorkedQuantity__c;
            this.lineType = pl.Type__c;
        }
    }
}