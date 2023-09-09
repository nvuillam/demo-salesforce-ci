public class LTNG_Picklist {


	@AuraEnabled
	public static PicklistConfig getPicklistConfig(String sObjectName, String fieldName){
		
		// 	HttpRequest req = new HTTPRequest();
		
		// //req.setEndpoint(URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v41.0/ui-api/object-info/Opportunite__c/picklist-values/012240000002d3H/TypeOperation__c');
		
		// req.setEndpoint('callout:This_SF/services/data/v41.0/ui-api/object-info/Opportunite__c/picklist-values/012240000002d3H/TypeOperation__c');
		
		// req.setMethod('GET');
		
		// req.setHeader('Content-Type', 'application/json');
		// //req.setHeader('Authorization', 'OAuth ' + UserInfo.getSessionId());
		// //req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
		
		// // Create a new http object to send the request object
		// // A response object is generated as a result of the request  
		
		// Http http = new Http();
		// HTTPResponse res = http.send(req);
		
		// system.debug(res.getBody());
		// return null;
		
		Schema.DescribeFieldResult fieldDescribe = getFieldDescribe(sObjectName, fieldName);
		
		PicklistConfig config = new PicklistConfig(fieldDescribe);
		
		//PicklistConfig config = new PicklistConfig();
	
		
		return config;
	}
	
	
	
	private static Schema.DescribeFieldResult getFieldDescribe(String sObjectName, String fieldName){
		return Schema.describeSObjects(new List<String>{sObjectName})[0].fields.getMap().get(fieldName).getDescribe();
	}
	
	
	
	
	
	
	
	
	public class PicklistConfig{
		
		@AuraEnabled public List<PicklistItem> options;
		@AuraEnabled public Boolean isDependent;
		@AuraEnabled public String controllingFieldName;
		
		public PicklistConfig(){
			this.options = new List<PicklistItem>();
		}
		
		public PicklistConfig(Schema.DescribeFieldResult fieldDescribe){
			
			this.options = new List<PicklistItem>();
			
			// Map<String, PicklistItem> optionsByValues = new Map<String, PicklistItem>();
			List<PicklistEntry> tempPicklistEntries = fieldDescribe.getPicklistValues();
			
			this.isDependent = fieldDescribe.isDependentPicklist();
			
			
			
			if(!this.isDependent){
				for(Schema.PicklistEntry pe : tempPicklistEntries){
					if(pe.isActive())
						options.add(new PicklistItem(pe));
				}	
			}
			else{
				
				Schema.DescribeFieldResult controllingField = fieldDescribe.getController().getDescribe();
				this.controllingFieldName = controllingField.getName();
				
				List<String> controllingValues = new List<String>();
				for (Schema.PicklistEntry pe : controllingField.getPicklistValues()) {
					controllingValues.add(pe.getValue());
				}
				
				List<PicklistItem> dependentFieldItems = wrapPicklistEntries(tempPicklistEntries);
				
				String tempValidForBits;
				String tempBit;
				for (PicklistItem pe : dependentFieldItems) {
					
					if(pe.active == 'true'){
						pe.availableFor = new List<String>();
						
						tempValidForBits = base64ToBits(pe.validFor);
						
						for (Integer i = 0; i < tempValidForBits.length(); i++) {
							// For each bit, in order: if it's a 1, add this label to the dependent list for the corresponding controlling value
							tempBit = tempValidForBits.mid(i, 1);
							if (tempBit == '1') {
								pe.availableFor.add(controllingValues.get(i));
							}
						}
						
						this.options.add(pe);
					}
				}
			}
			
			
		}
	}
	
	
	
	public class PicklistItem{
		
		@AuraEnabled public String value; 
		@AuraEnabled public String label;
		
		@AuraEnabled public List<String> availableFor;
		
		//Uniquement nécessaires pour la déserialisation des PicklistEntry
		private String active {get; set;}
		private String validFor {get; set;}
		
		
		
		public PicklistItem(Schema.PicklistEntry pe){
			this.value = pe.value;
			this.label = pe.label;
		}
		
	}
	
	
	
	
	
	
	
	
	
	
	
	private static List<PicklistItem> wrapPicklistEntries(List<Schema.PicklistEntry> PLEs) {
		return (List<PicklistItem>) JSON.deserialize(JSON.serialize(PLEs), List<PicklistItem>.class);
	}
	
	
	
	// Convert decimal to binary representation (alas, Apex has no native method :-(
	//    eg. 4 => '100', 19 => '10011', etc.
	// Method: Divide by 2 repeatedly until 0. At each step note the remainder (0 or 1).
	// These, in reverse order, are the binary.
	private static String decimalToBinary(Integer val) {
		String bits = '';
		while (val > 0) {
			Integer remainder = Math.mod(val, 2);
			val = Integer.valueOf(Math.floor(val / 2));
			bits = String.valueOf(remainder) + bits;
		}
		return bits;
	}


	// Convert a base64 token into a binary/bits representation
	// e.g. 'gAAA' => '100000000000000000000'
	private static String base64ToBits(String validFor) {
		if (String.isEmpty(validFor)) return '';

		String validForBits = '';

		for (Integer i = 0; i < validFor.length(); i++) {
			String thisChar = validFor.mid(i, 1);
			Integer val = ('' +
			'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
			'abcdefghijklmnopqrstuvwxyz' +
			'0123456789+/').indexOf(thisChar);
			String bits = decimalToBinary(val).leftPad(6, '0');
			validForBits += bits;
		}

		return validForBits;
	}
	
}