public class BusinessAnalyticsManager {

    //public ProjectLine__c projectLine {get;set;}
    
    public PreFacture__c [] Factures{get;set;}
    
    public Map<Id, ProjectLine__c> projectLinesForTsCalculation{get;set;}
    
    public TimeSheet__c[] TsOfTheMonth{get;set;}

    public TimeSheet__c[] TsOfPreviousMonth{get;set;}
    
    public Date currentMonth{get;set;}
    
    public Boolean selected{get;set;}
    
    public BusinessAnalytic__c storedBa{get;set;}
    
    public BusinessAnalytic__c calculatedBa{get;set;}
    
    private transient BusinessAnalytic__c prevBA;

    public static Boolean forceProjectRAF{get;set;} // Si on vien de mettre a jours les RAF, c'est qu'on veut se baser dessus pour nos B



    private static transient Map<String, DescribeFieldResult > BADescribe;

    static{
       // addedProjectLinesId = new set<Id>();
        forceProjectRAF = false;
        BADescribe = new Map<String, DescribeFieldResult>();
        for(SObjectField f : BusinessAnalytic__c.SObjectType.getDescribe().fields.getMap().values()){
            DescribeFieldResult  sf = f.getDescribe();
            BADescribe.put(sf.getName(),sf);
        }
    }





    public static String getProjectLineQuery(){
        return 'SELECT id, Name, SectionAnalytique__c, SoldQuantity__c,WorkedQuantity__c,SoldAmount__c,RevisedQuantity__c,LigneFormatee__c,NumeroDeLigne__c,Project__r.ProjetFormate__c,Project__r.CodeProjetWebSi__c, Project__r.Account__r.Code_client__c,Project__r.CalculDeTFNR__c,CalculDeTFNR__c,'+
                '(SELECT id, PreFacture__r.date_emission__c,InvoicedAmount__c,SectionAnalytique__c from LignesFacture__r where PreFacture__r.Non_comprise_dans_le_CA__c = false order by PreFacture__r.date_emission__c ASC),'+
                '(SELECT id, Date__c, DurationTotal__c, Type__c, BusinessAnalytic__c,businessAnalytic__r.ExternalId__c, ProjectLine__c, ProjectLine__r.UnitRate__c, ProjectLine__r.RevisedQuantity__c from timesheets__r where type__c != \'Pre-sales\' order by date__c ASC),'+
                '(SELECT id, Montant__c, nbJours__c, Date__c,SectionAnalytique__c from affectationsActifs__r order by Date__c ASC),'+
                '(SELECT id, SectionAnalytique__c, ExternalId__c,Statut__c,ResteAFaireEstime__c ,NbJoursRealises__c,NbJoursRealisesCeMois__c,CaRealiseBA__c,CAFacture__c,CACommande__c, date__c, TRNF__c, TRNFPrecedent__c from BusinessAnalytics__r order by date__c DESC)'+
                ' FROM ProjectLine__c';
    }




    public static Map<String, BusinessAnalyticsManager> init(Id[] ProjectLinesId, Date workDate){
		System.debug('BusinessAnalyticsManager.init() ' + ProjectLinesId + ' / ' + workDate.format());
        Map<String, BusinessAnalyticsManager> ret = new Map<String, BusinessAnalyticsManager>();
        workDate = workDate.toStartOfMonth();
        Date workDatem1 = workDate.toStartOfMonth().addMonths(1).addDays(-1); //Si on fait sur octobre, on stocke 31/10 ici
        String WhereClause = ProjectLinesId == null || ProjectLinesId.isEmpty() ? 'AND ( Active__c=true or ( project__r.DerniereTS__c >=: workDate AND project__r.DerniereTS__c <= :workDatem1 ) )' : 'AND (Project__c IN: ProjectLinesId OR Id in :ProjectLinesId )';
        String query = BusinessAnalyticsManager.getProjectLineQuery()+' WHERE type__c IN (\'Forfait\',\'Régie Plafonnée\' )'+WhereClause;
        query += ' ORDER BY Project__r.CodeProjetWebSi__c , NumeroDeLigne__c ASC';

        //Récupération des BA existant
        Set<Id> ExistingVerrouilledBa = new Set<Id>();
        Date dateBA = workDate.toStartOfMonth();
        for( BusinessAnalytic__c ba : [SELECT Id, ProjectLine__c, Project__c FROM BusinessAnalytic__c WHERE Verrouille__c = TRUE AND Date__c =:DateBA AND ( Project__c IN : ProjectLinesId OR Project__c IN : ProjectLinesId)] ){
            ExistingVerrouilledBa.add(ba.ProjectLine__c == null ? ba.Project__c : ba.ProjectLine__c);
        }

        List<Id> projectsToRetrieveBas = new List<Id>();

        for(projectLine__c pl : (ProjectLine__c[]) database.query( query )){
            String key = (pl.CalculDeTFNR__c == 'Par Projet' ?  pl.Project__c : pl.Id) + '-' + pl.SectionAnalytique__c;
            if(pl.CalculDeTFNR__c == 'Par Projet' ) {

                if(!ExistingVerrouilledBa.contains(pl.Project__c)) {
                    if (!ret.containsKey(key)) {
                        projectsToRetrieveBas.add(pl.Project__c);
                        ret.put(key, new BusinessAnalyticsManager(pl, workDate));
                    } else {
                        ret.get(key).addPl(pl);
                    }
                }
            }else if(!ExistingVerrouilledBa.contains(pl.Id)){
                ret.put(key, new BusinessAnalyticsManager(pl, workDate));

            }
        }

        if(!projectsToRetrieveBas.isEmpty()){
            for(BusinessAnalytic__c ba : [SELECT id,SectionAnalytique__c, ExternalId__c, Project__c,Statut__c,ResteAFaireEstime__c ,NbJoursRealises__c,NbJoursRealisesCeMois__c,CaRealiseBA__c,CAFacture__c,CACommande__c, date__c, TRNF__c, TRNFPrecedent__c from BusinessAnalytic__c WHERE Project__c IN :projectsToRetrieveBas AND Date__c <= : workDate order by date__c DESC]){
                String key = ba.Project__c + '-' + ba.SectionAnalytique__c;
                system.debug('storedBA : '+ key + ' search in '+ret.keySet());
                if(ret.containsKey(key) && ba.Date__c.toStartOfMonth() == ret.get(key).currentMonth){
                    ret.get(key).storedBa = ba;
                }
                system.debug('is this a previous BA ? '+key+' '+ba.Date__c+ '/ '+workDate.toStartOfMonth());
                if( ret.containsKey(key) && ret.get(key).prevBA == null && ba.Date__c == workDate.toStartOfMonth().addDays(-1).toStartOfMonth() ){
                    system.debug('Yes It Is');
                    ret.get(key).prevBA = ba;
                }else System.debug('No It Is not');
            }
        }
        for(BusinessAnalyticsManager ba : ret.values()){
            ba.initCalculatedBa();
        }
        return ret;

    }

    public void addPL(ProjectLine__c pl){
        this.addTimesheets(pl.TimeSheets__r);
        this.addLignesFactures( pl.LignesFacture__r );
        this.addAffectationsActifs( pl.AffectationsActifs__r );
        if(this.calculatedBa.QtiteReactualisee__c == null)
            this.calculatedBa.QtiteReactualisee__c = 0;
        system.debug('Calculated BA '+this.calculatedBa.QtiteReactualisee__c +' revised '+pl.RevisedQuantity__c+ ' sold '+pl.SoldQuantity__c);
        this.calculatedBa.QtiteReactualisee__c += pl.RevisedQuantity__c == null ? pl.SoldQuantity__c : pl.RevisedQuantity__c;
        system.debug('New Quantite '+this.calculatedBa.QtiteReactualisee__c);
    }
    
    public BusinessAnalyticsManager(ProjectLine__c pl, Date d ){
        this.selected = false;
		this.projectLinesForTsCalculation = new Map<Id, ProjectLine__c>();
        this.TsOfTheMonth = new TimeSheet__c[]{};
        this.TsOfPreviousMonth = new TimeSheet__c[]{};
        //this.projectLine = pl.clone(true, true);

        this.currentMonth = d.toStartOfMonth();
        this.calculatedBa = createEmptyBA(this.currentMonth, pl);

        Date prev = this.currentMonth.addDays(-1);
        this.prevBA = null;

        for(BusinessAnalytic__c ba : pl.BusinessAnalytics__r){
            if(ba.Date__c == this.currentMonth.addMonths(1).addDays(-1)){
                this.storedBa = ba; 
            }
            if(this.prevBA == null && ba.Date__c <= prev){
                this.prevBA = ba;
                break;
            }
        }
        this.addPL(pl);
        this.initCalculatedBa( );
        if(this.prevBA != null)
        	this.calculatedBa.Precedent__c = this.prevBA.Id;
    }

    private void addTimesheets(TimeSheet__c[] ts){

        for(TimeSheet__c t : ts){
			this.projectLinesForTsCalculation.put(t.ProjectLine__c, t.ProjectLine__r);
            if(t.Date__c.toStartOfMonth() <= this.currentMonth) {
                this.calculatedBa.NbJoursRealises__c += t.DurationTotal__c;
                if(t.Date__c.toStartOfMonth() == this.currentMonth) {
                    this.calculatedBa.NbJoursRealisesCeMois__c += t.DurationTotal__c;
                    this.TsOfTheMonth.add(new TimeSheet__c(Id=t.Id, DurationCustomer__c = t.DurationTotal__c, ProjectLine__c = t.ProjectLine__c));
                }else if(t.BusinessAnalytic__c == null || t.businessAnalytic__r.ExternalId__c == this.calculatedBa.ExternalId__c){
                    this.TsOfPreviousMonth.add(new TimeSheet__c(Id=t.Id, DurationCustomer__c = t.DurationTotal__c));
                    this.calculatedBa.NBJoursRattrapes__c += t.DurationTotal__c;
                }
            }
        }
    }

    private void addLignesFactures(LigneFacture__c[] fs){
        for(LigneFacture__c f : fs){
            if(f.PreFacture__r.Date_emission__c.toStartOfMonth() <= this.currentMonth){
                this.calculatedBa.CAFacture__c += f.InvoicedAmount__c;
                if(f.PreFacture__r.Date_emission__c.toStartOfMonth() == this.currentMonth)
                    this.calculatedBa.CAFactureCeMois__c += f.InvoicedAmount__c;
            }
        }
    }

    private void addAffectationsActifs(AffectationActif__c[] afs){
        for(AffectationActif__c af : afs){
            if(af.Date__c != null && af.Date__c.toStartOfMonth() <= this.currentMonth){
                this.calculatedBa.CACommande__c += af.Montant__c;
                this.calculatedBa.NbJoursVendus__c += af.NbJours__c;
            }
        }
    }




    
    private void initCalculatedBa( ){


        this.calculatedBa.TRNFPrecedent__c = 0;
        /*if( this.storedBa != null ){
            this.calculatedBa.TRNFPrecedent__c = this.storedBa.TRNFPrecedent__c == null ?  0:this.storedBa.TRNFPrecedent__c;

        }
        else
        */
        if(this.prevBA != null){
            this.calculatedBa.TRNFPrecedent__c = this.prevBA.TRNF__c == null ? 0 : this.prevBA.TRNF__c;
            this.calculatedBa.Precedent__c = this.prevBA.id;
        }
        

        decimal revisedQuantity = this.calculatedBa.QtiteReactualisee__c;
       // System.debug('Setting RAF to BA' + revisedQuantity);
        this.calculatedBa.ResteAFaireEstime__c = revisedQuantity - this.calculatedBa.NbJoursRealises__c;

        //this.projectLine.RevisedQuantity__c = revisedQuantity;
        //Decimal qtiteReactualisee = revisedQuantity;
        //this.calculatedBa.QtiteReactualisee__c = qtiteReactualisee;
        system.debug('Calcul TRNF');
        system.debug('n Jours réalisé '+ this.calculatedBa.NbJoursRealises__c +' qtité réac '+ this.calculatedBa.QtiteReactualisee__c );
        system.debug('CA Commandé '+ this.calculatedBa.CACommande__c +' CA Facturé '+ this.calculatedBa.CAFacture__c );

        if( this.calculatedBa.QtiteReactualisee__c > 0 ){
            Decimal avancement = this.calculatedBa.NbJoursRealises__c / this.calculatedBa.QtiteReactualisee__c;
            this.calculatedBa.TRNF__c = ( avancement * this.calculatedBa.CACommande__c ) - this.calculatedBa.CAFacture__c;
            this.calculatedBa.CaRealiseBA__c = this.calculatedBa.TRNF__c + this.calculatedBa.CAFactureCeMois__c - this.calculatedBa.TRNFPrecedent__c;
        }
        
        //this.calculatedBa = ba;
    }
    
    public List<TimeSheet__c> updateTimesheets(){
        List<TimeSheet__c> ret = new List<TimeSheet__c>();
        system.debug('Putting CA realisé into timesheets');
        system.debug(this.calculatedBa);
		ProjectLine__c projectLine;
        for(TimeSheet__c t : this.TsOfTheMonth){
			projectLine = this.projectLinesForTsCalculation.get(t.ProjectLine__c);
            if(this.calculatedBa.NbJoursRealisesCeMois__c != null) {
				System.debug(t.DurationCustomer__c +'*'+ projectLine.UnitRate__c +'/'+ projectLine.RevisedQuantity__c);
                ret.add(new TimeSheet__c(
					Id = t.Id, BusinessAnalytic__r = new BusinessAnalytic__c(ExternalId__c = this.calculatedBa.ExternalId__c), 
					//CARealise__c = t.DurationCustomer__c * this.calculatedBa.CaRealiseBA__c / this.calculatedBa.NbJoursRealisesCeMois__c));
					CARealise__c = t.DurationCustomer__c * projectLine.UnitRate__c / projectLine.RevisedQuantity__c));
            }
        }
        //On affecte un CA de 0 au jours de rattrapages, le CA sera automatiquement mis sur les prochaines ts.
        for(TimeSheet__c t : this.TsOfPreviousMonth){
            ret.add(new TimeSheet__c(Id = t.Id, BusinessAnalytic__r = new BusinessAnalytic__c(ExternalId__c = this.calculatedBa.ExternalId__c), CARealise__c = 0));
        }

        return ret;
    }



    public static String generateExternalId(Date d, Id ProjectLineId, String sectionAnalytique){
        Datetime key = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        String ExtId = ProjectLineId + '_'+sectionAnalytique+'_'+key.format('MMYYYY');
        return ExtId;
    }

    public static BusinessAnalytic__c createEmptyBA(Date d, ProjectLine__c projectLine){
        BusinessAnalytic__c ba = new BusinessAnalytic__c(Date__c = d.toStartOfMonth(),NbJoursRealises__c = 0,NbJoursRealisesCeMois__c = 0,CAFacture__c=0,CAFactureCeMois__c=0,CACommande__c=0, NbJoursVendus__c=0,NbJoursRattrapes__c = 0);
        if(projectLine != null){
            ba.ExternalId__c = generateExternalId(d, projectLine.CalculDeTFNR__c == 'Par Projet' ? projectLine.Project__c : projectLine.Id, projectLine.SectionAnalytique__c);
            ba.Project__c = projectLine.Project__c;
            ba.SectionAnalytique__c =  projectLine.SectionAnalytique__c;
            ba.Name = getMonthLocale(d.month()) + ' ' + d.year()+ ' '+projectLine.SectionAnalytique__c;
            if(  projectLine.CalculDeTFNR__c == 'Par Projet' ){
                ba.Name += ' Projet '+projectLine.Project__r.CodeProjetWebSI__c;
            }else {
                ba.Name += ' Ligne '+ projectLine.NumeroDeLigne__c;
                ba.ProjectLine__c = projectLine.Id;
            }
        }
        return ba;
    }

    public static String getMonthLocale(Integer monthNumber){
        String[] Months = new String []{'Janvier','Février','Mars','Avril','Mai','Juin','Juillet','Août','Septembre','Octobre','Novembre','Décembre'};
        return Months.get(monthNumber -1);
    }
}