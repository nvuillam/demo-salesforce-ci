public class TimeSheetQuickCreateCtrl{
  
  public List<Date> last5days {get;set;}
  public Map<Date, Decimal> durationsByDates {get;set;}
  public Map<Date, String> dayNamesByDates {get;set;}
  public String dateStr {get;set;}
  
  public TimeSheet__c timeSheet {get; set;}
  
  public List<SelectOption> projects {get; set;}
  
  public Boolean saved {get; set;}
  
  public String projectIdsWithMandatoryDescriptionJSON {get; set;}

  public Map< String, List<ProjectLineTupple> > projectToLines{get;set;}
  public String projectToLinesJSON{get;set;}

    public Date startDate{get;set;}
  
  
  public TimeSheetQuickCreateCtrl(){

      this.startDate = date.today();
      this.initAll();



  }

    public void initAll(){
        system.debug('initAll'+this.startDate);
        this.initLast5days();

        this.initNewTimeSheet();

        this.initDurations();

        this.initProjects();
    }
  
  public pageReference prevWeek(){
      this.startDate = this.last5days.get(0).addDays(-1);
      this.initAll();
      return null;
  }
    public pageReference nextWeek(){
        this.startDate = this.last5days.get(0).addDays(13);
        this.initAll();
        return null;
    }

    public pageReference curWeek(){
        this.startDate = date.today();
        this.initAll();
        return null;
    }
  
  
  public void saveTimeSheet(){
    List<String> dateSplit = this.dateStr.split('-');
    this.timeSheet.Date__c = date.newinstance(Integer.valueOf(dateSplit[0]), Integer.valueOf(dateSplit[1]), Integer.valueOf(dateSplit[2]));
    
    
    //S'il existe une TS pour le même jour, même projet, même type et même user, alors on ne créé pas une nouvelle TS mais on modifie la durée de la première
    List<TimeSheet__c> dupeTimeSheet = [SELECT Id, Duration__c, Description__c FROM TimeSheet__c WHERE User__c = :UserInfo.getUserId() AND Date__c = :this.timeSheet.Date__c AND Project__c = :this.timeSheet.Project__c AND Type__c = :this.timeSheet.Type__c LIMIT 1];
    if(!dupeTimeSheet.isEmpty()){
      dupeTimeSheet[0].Duration__c += this.timeSheet.Duration__c;
      if(String.isNotBlank(this.timeSheet.Description__c))
      dupeTimeSheet[0].Description__c = (String.isBlank(dupeTimeSheet[0].Description__c) ? '' : dupeTimeSheet[0].Description__c + '\n') + this.timeSheet.Description__c;
      
      update dupeTimeSheet[0];
    }
    else
      insert this.timeSheet;
    
    this.initNewTimeSheet();
    this.initDurations();
    this.saved = true;
  }
  
  
  private void initNewTimeSheet(){
    this.timeSheet = new TimeSheet__c(Date__c = this.last5days[this.last5days.size() - 1], Duration__c = 1, Type__c = 'Technical', User__c = UserInfo.getUserId(), Description__c = '');
    
    
    //Récupère la dernière TimeSheet qu'on a saisi
    List<TimeSheet__c> ts = [SELECT Id, Date__c, projectLine__c,ProjectMember__c, Duration__c, Type__c, Project__c, CreatedDate FROM TimeSheet__c WHERE User__c = :UserInfo.getUserId() ORDER BY CreatedDate DESC LIMIT 1];
    
    if( !ts.isEmpty()){
      
      //On selectionne par défaut le dernier Type et le dernier Projet utilisé
      this.timeSheet.Type__c = ts[0].Type__c;
      this.timeSheet.Project__c = ts[0].Project__c;
      this.timeSheet.ProjectLine__c = ts[0].ProjectLine__c;
        this.timeSheet.ProjectMember__c = ts[0].ProjectMember__c;
      //Si la dernière TimeSheet date d'aujourd'hui, on selectionne également par défaut la dernière Date et la dernière Durée utilisée
      if(ts[0].CreatedDate.date() == system.today() && ts[0].Date__c >= this.last5days[0] && ts[0].Date__c <= this.last5days[4]){
        this.timeSheet.Date__c = ts[0].Date__c;
        this.timeSheet.Duration__c = ts[0].Duration__c;
      }
    }
    
    
    this.dateStr = this.timeSheet.Date__c.year() + '-' + this.timeSheet.Date__c.month() + '-' + this.timeSheet.Date__c.day();
  }
  
  
  private void initLast5days(){
    this.last5days = new List<Date>();
    
    this.dayNamesByDates = new Map<Date, String>();
    
    Date tempDate = this.startDate;
    while(last5days.size() < 5){
      
      if(Integer.valueOf( ((DateTime) tempDate).format('u')) < 6){
        this.last5days.add(tempDate);
        this.dayNamesByDates.put(tempDate, ((DateTime) tempDate).format('E dd'));
        
      }
      tempDate = tempDate.addDays(-1);
    }
    
    this.last5days.sort();
  }
  
  
  
  private void initDurations(){
    
    this.durationsByDates = new Map<Date, Decimal>();
    
    for(Date d : this.last5days)
    this.durationsByDates.put(d, 0);
    
    
    for(AggregateResult aggr : [SELECT Date__c, SUM(Duration__c) totalTime FROM TimeSheet__c WHERE User__c = :UserInfo.getUserId() AND Date__c IN :this.last5days GROUP BY Date__c]){
      this.durationsByDates.put((Date) aggr.get('Date__c'), (Decimal) aggr.get('totalTime'));
    }
  }
  
  
  private void initProjects(){
    this.projects = new List<SelectOption>();
    this.projectToLines = new map<String, List<ProjectLineTupple>>();

    Set<Id> projectIdsWithMandatoryDescription = new Set<Id>();
    List<Project__c> addedProjects = new List<Project__c>();
      Map<Id,ProjectMember__c> emptyProjectMembers = new map<Id,ProjectMember__c>();
    String account;
    for(Project__c p : [SELECT Id, Account__r.Name, Name, RequireTimeSheetDescription__c,(SELECT Id , User__c from ProjectMembers__r WHERE user__c =:UserInfo.getUserId() AND projectLine__c = null LIMIT 1 ) FROM Project__c WHERE IsActive__c = true AND Id IN (SELECT Project__c FROM ProjectMember__c WHERE User__c = : UserInfo.getUserId() ) ORDER BY Account__r.Name, Name]){
      if(account != p.Account__r.Name){
        this.projects.add(new SelectOption('', p.Account__r.Name, true));
        account = p.Account__r.Name;
      }
      if(!p.projectMembers__r.isEmpty())
          emptyProjectMembers.put(p.id, p.projectMembers__r.get(0));
      this.projects.add(new SelectOption(p.Id, '    ' + p.Name));    //4 espaces insécables (ALT+255)
      addedProjects.add(p);
      if(p.RequireTimeSheetDescription__c)
		projectIdsWithMandatoryDescription.add(p.Id);
	}

    for(ProjectLine__c pl : [SELECT id, Name,project__c,NumeroDeLigne__c, ( SELECT Id,User__c FROM LineMembers__r ) FROM ProjectLine__c WHERE Project__c IN : addedProjects AND Active__c = true Order By NumeroDeLigne__c]){
      if(pl.LineMembers__r.isEmpty() && emptyProjectMembers.containsKey(pl.project__c)) {
        this.addLineToMap( pl,emptyProjectMembers.get( pl.project__c ) );
      }else{
        for(ProjectMember__c pm : pl.LineMembers__r){
          if(pm.User__c == userInfo.getUserId()) {
            this.addLineToMap(pl,pm);
            break;
          }
        }
      }
    }

    this.projectToLinesJSON = JSON.serialize(this.projectToLines);
	this.projectIdsWithMandatoryDescriptionJSON = JSON.serialize(projectIdsWithMandatoryDescription);
  }

  private void addLineToMap(projectLine__c pl,projectMember__c pm){
    if(!this.projectToLines.containsKey(pl.project__c))
      this.projectToLines.put(pl.project__c, new ProjectLineTupple[]{});
    this.projectToLines.get(pl.project__c).add(new ProjectLineTupple(pl,pm));
  }

    public class projectLineTupple{
        public Id lineId {get;set;}
        public String lineName{get;set;}
        public Id pmId{get;set;}
        public projectLineTupple(ProjectLine__c pl , ProjectMember__c pm){
            this.lineId = pl.id;
            this.lineName = pl.Name;
            this.pmId = pm.id;
        }
    }
  
  
}