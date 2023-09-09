/**
 * Created by DHU on 15/10/2018.
 */

public with sharing class LTNG02_ProjectSetup {
    @auraEnabled public static projectDescriptorWrapper initProject(Id recordId){
        Project__c p = new Project__c();
        if(recordId != null){
            p = [SELECT Id, Name, Type__c,
                    ( SELECT Id, Name,Type__c, NumeroDeLigne__c,SectionAnalytique__c, Active__c, InitialQuantity__c, revisedQuantity__c,  UnitRate__c, SoldAmount__c, SoldQuantity__c, WorkedAmount__c, WorkedQuantity__c FROM ProjectLines__r order by NumeroDeLigne__c ASC),
                    ( SELECT id, User__r.Name, User__r.EmployeeNumber , ProjectLine__c FROM ProjectMembers__r order by User__r.Name )
                 FROM Project__c Where Id =: recordId];
        }
        User CurrentUser = [SELECT Id, SectionAnalytique__c FROM User WHERE Id=:userInfo.getUserId()];
        projectDescriptorWrapper ret =  new projectDescriptorWrapper(p);
        ret.currentAnalytic = CurrentUser.SectionAnalytique__c;
        return ret;
    }

    /*@auraEnabled public static MemberWrapper[] loadFlattened(String flattened, String currentJSON){
        List<Id> usersId = flattened.split(';');
        MemberWrapper[] ret = new List<MemberWrapper>();
        List<MemberWrapper> current = (List<MemberWrapper>) JSON.deserialize(currentJSON,List<MemberWrapper>.class);
        Map<Id, MemberWrapper> currentsById = new Map<Id, MemberWrapper>();
        for(MemberWrapper m : current){
            currentsById.put(m.userId, m);
        }
        for(User u : [SELECT Id, Name, EmployeeNumber FROM User WHERE id in : usersId ORDER BY Name]){
            if(currentsById.containsKey(u.id))
                ret.add(currentsById.get(u.id));
            else
                ret.add(new MemberWrapper(u));
        }
        return ret;
    }*/

    @AuraEnabled public static ProjectDescriptorWrapper destroyLines(String linesJSON, Id projectId){
        List<ProjectLine__c> LinesTodel = new List<ProjectLine__c>();
        List<lineWrapper> lines = (List<lineWrapper>) JSON.deserialize(linesJSON,List<lineWrapper>.class);
        for( lineWrapper l : lines ){
            system.debug(l);
            LinesTodel.add( new ProjectLine__c( Id = l.id ) );
        }
        delete LinesTodel;
        return initProject(projectId);
    }

    @AuraEnabled public static ProjectDescriptorWrapper upsertLines( String linesJSON, Id projectId ){
        List<ProjectLine__c> LinesToUp = new List<ProjectLine__c>();
        //system.debug(linesJSON);
        List<lineWrapper> lines = (List<lineWrapper>) JSON.deserialize(linesJSON,List<lineWrapper>.class);
        System.debug(lines);
        for( lineWrapper l : lines ){
            LinesToUp.add( l.tosObject( projectId ) );
        }
        System.debug('Upserting '+linesToUp);
        upsert LinesToUp;

        Map<String, ProjectMember__c> membersToUp = new Map<String, ProjectMember__c> ();
        for( LineWrapper l : lines ){
            for(ProjectMember__c pm : l.createMembers()){
                pm.Project__c = projectId;
                membersToUp.put( pm.ProjectLine__c+'_'+pm.User__c, pm );
            }
        }
        upsert membersToUp.values();
        System.debug('Upserting '+membersToUp);

        //Delete unseted projectMembers
        List<ProjectMember__c> pmToDel = [SELECT id FROM ProjectMember__c WHERE Project__c = :projectId AND ProjectLine__c IN : LinesToUp AND Id NOT IN : membersToUp.values() ];
        System.debug(pmToDel.size()+' projectMembers to delete');
        if(!pmToDel.isEmpty())
            delete pmToDel;
        List<AffectationActif__c> AAToCreate = new List<AffectationActif__c>();
        for( LineWrapper l : lines ){
            AffectationActif__c aa = l.createAA();
            if(aa != null)
                AAToCreate.add(aa);
        }
        if(!AAToCreate.isEmpty())
            insert AAToCreate;

        return initProject(projectId);
    }

    @AuraEnabled public static ProjectDescriptorWrapper ImOnTheLine(Id lineId){
        System.debug('IN ImOnTheLine =>'+LineId);
        ProjectLine__c p = [SELECT id, Project__c, ( SELECT id, User__c FROM LineMembers__r WHERE User__c = :userInfo.getUserId() ) FROM ProjectLine__c WHERE Id = :LineId LIMIT 1];
        if(p.LineMembers__r.isEmpty())
            upsert new ProjectMember__c(Project__c = p.Project__c, ProjectLine__c = LineId, User__c = UserInfo.getUserId());
        else
                delete p.LineMembers__r;
        return initProject(p.Project__c);
    }

    @auraEnabled public static boolean updateActiveLineStatus(Id lineId, Boolean isActive){
        update new ProjectLine__c(id = lineId, Active__c=isActive);
        return true;
    }

     public class projectDescriptorWrapper{
        @auraEnabled public Id projectId;
        @auraEnabled public String defaultLineType;
        @auraEnabled public String currentAnalytic;
        @auraEnabled public LineWrapper[] lines{get;set;}
       // @auraEnabled public MemberWrapper[] members{get;set;}

        public projectDescriptorWrapper(Project__c p){
            this.projectId = p.id;
            this.defaultLineType = p.Type__c;
            this.lines = new lineWrapper[]{};
            for(ProjectLine__c l : p.projectLines__r){
                this.lines.add(new lineWrapper(l));
            }
            for(ProjectMember__c pm : p.ProjectMembers__r){
                for(lineWrapper lw : this.lines){
                    if(pm.ProjectLine__c == lw.id){
                        lw.addMember(pm);
                        break;
                    }
                }
            }

            system.debug('projectDescriptorWrapper'+this);
        }
    }

     public class lineWrapper{
         public ProjectLine__c createdsObject;
        @auraEnabled public String name;
        @auraEnabled public AffectationActif__c relatedAffectationActif;
        @auraEnabled public String id;
        @auraEnabled public String type;
        @auraEnabled public String analytic;
        @auraEnabled public decimal codeWebSi;
        @auraEnabled public boolean editable;
        @auraEnabled public boolean editableInitSettings;
        @auraEnabled public boolean deletable;
        @auraEnabled public Decimal TJ;
        @auraEnabled public Decimal revisedQuantity;
        @auraEnabled public Decimal initialQuantity;
        @auraEnabled public Decimal soldAmount;
        @auraEnabled public Decimal soldQuantity;
        @auraEnabled public Decimal workedQuantity;
        @auraEnabled public Boolean isActive;
        @auraEnabled public boolean imonit;
        @auraEnabled public MemberWrapper[] members;
         @auraEnabled public String flattenedMembers;

        public LineWrapper (ProjectLine__c l){
            this.name = l.Name;
            this.id = l.Id;
            this.type = l.Type__c;
            this.analytic = l.SectionAnalytique__c;
            this.codeWebSi = l.NumeroDeLigne__c;
            this.tj = l.UnitRate__c;
            this.revisedQuantity = l.RevisedQuantity__c;
            this.initialQuantity = l.InitialQuantity__c;
            this.soldAmount = l.SoldAmount__c;
            this.soldQuantity = l.soldQuantity__c;
            this.workedQuantity = l.WorkedQuantity__c;
            this.members = new List<MemberWrapper>();
            this.editableInitSettings = workedQuantity == 0;
            this.deletable = workedQuantity == 0 && soldQuantity == 0;
            this.flattenedMembers = '';
            this.isActive = l.Active__c;
        }

         public void addMember(ProjectMember__c pm){
             this.members.add(new MemberWrapper(pm));
             if(pm.User__c == UserInfo.getUserId())
                 this.imonit = true;
             if(this.flattenedMembers != '')
                 this.flattenedMembers +=';';
             this.flattenedMembers += pm.User__c;
         }

         public ProjectLine__c tosObject(Id ProjectId){
             System.debug('in toSobject');
             if(this.codeWebSi== null)
                 this.codeWebSi = 0;
             this.createdsObject = new ProjectLine__c(
                     Id = this.id,
                     Project__c = projectId,
                     Name = this.name,
                     Type__c = this.type,
                     NumeroDeLigne__c = this.codeWebSi,
                     UnitRate__c = this.TJ,
                     RevisedQuantity__c = this.revisedQuantity,
                     InitialQuantity__c = this.initialQuantity
             );
             
             System.debug('out toSobject '+this.createdsObject);
             return this.createdsObject;
         }

         public ProjectMember__c[] createMembers(){
             List<ProjectMember__c> ret = new List<ProjectMember__c>();
             //On fait ca a partir du flattend member qui est plus fiable.
             if(this.flattenedMembers != '0' && this.flattenedMembers != null && this.flattenedMembers.length()>14) {
                 String[] uids = this.flattenedMembers.split(';');

                 for (String uid : uids) {
                     ret.add(new ProjectMember__c(ProjectLine__c = this.createdsObject.Id, User__c = (Id) uid));
                 }
             }
             return ret;
         }

         public AffectationActif__c createAA(){
             AffectationActif__c ret = relatedAffectationActif;
             if(ret != null) {
                 ret.ProjectLine__c = this.createdsObject.id;
             }
             return ret;

         }

    }

    public class MemberWrapper{
        @AuraEnabled public Id id;
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        public MemberWrapper (ProjectMember__c pm){
            this.id = pm.id;
            this.userId = pm.User__c;
            this.name = pm.User__r.Name;
        }
       /* public MemberWrapper (User u){
            this.userId = u.id;
            this.name = u.Name;
        }*/
    }
}