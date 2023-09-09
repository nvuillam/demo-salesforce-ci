/**
 * Class TriggerFactory
 * @Author Tony Scott
 * @Date 2012-04-02
 * @Site http://developer.force.com/cookbook/recipe/trigger-pattern-for-tidy-streamlined-bulkified-triggers
 * @Description Used to instantiate and execute Trigger Handlers associated with sObjects.
 */
public without sharing class TriggerFactory
{
	/**
	 * Public static method to create and execute a trigger handler
	 *
	 * Arguments:	Schema.sObjectType soType - Object type to process (SObject.sObjectType)
	 *
	 * Throws a MyException if no handler has been coded.
	 */
	public static void createHandler(Schema.sObjectType soType) {
		// Get a handler appropriate to the object being processed
		ITrigger handler = getHandler(soType);
		
		// Execute the handler to fulfil the trigger
		execute(handler);
	}
	
	/**
	 * private static method to control the execution of the handler
	 *
	 * Arguments:	TriggerHandlerBase handler - A Trigger Handler to execute
	 */	
	private static void execute(ITrigger handler) {
		// Before Trigger
		if (Trigger.isBefore)
		{
			// Call the bulk before to handle any caching of data and enable bulkification
			handler.bulkBefore();
			
			// Iterate through the records to be deleted passing them to the handler.
			if (Trigger.isDelete)
			{
				for (SObject so : Trigger.old)
				{
					handler.beforeDelete(so);
				}
			}
			// Iterate through the records to be inserted passing them to the handler.
			else if (Trigger.isInsert)
			{
				for (SObject so : Trigger.new)
				{
					handler.beforeInsert(so);
				}
			}
			// Iterate through the records to be updated passing them to the handler.
			else if (Trigger.isUpdate)
			{
				for (SObject so : Trigger.old)
				{
					handler.beforeUpdate(so, Trigger.newMap.get(so.Id));
				}
			}
		}
		else
		{
			// Call the bulk after to handle any caching of data and enable bulkification
			handler.bulkAfter();
			
			// Iterate through the records deleted passing them to the handler.
			if (Trigger.isDelete)
			{
				for (SObject so : Trigger.old)
				{
					handler.afterDelete(so);
				}
			}
			// Iterate through the records inserted passing them to the handler.
			else if (Trigger.isInsert || Trigger.isUndelete)
			{
				for (SObject so : Trigger.new)
				{
					handler.afterInsert(so);
				}
			}
			// Iterate through the records updated passing them to the handler.
			else if (Trigger.isUpdate)
			{
				for (SObject so : Trigger.old)
				{
					handler.afterUpdate(so, Trigger.newMap.get(so.Id));
				}
			}
		}
		
		// Perform any post processing
		handler.andFinally();
	}

	public static boolean isChanged( String fields, sObject oldSo, sObject newSo ){
		if(oldSo == null)
			oldSo = newSo.getSobjectType().newSObject();
		boolean ret = false;
		List<String> lField = fields.split(',');
		for(String f:lField)
			ret = ret || oldSo.get(f) != newSo.get(f);
		return ret;
	}
	
	/**
	 * private static method to get the appropriate handler for the object type.
	 * Modify this method to add any additional handlers.
	 *
	 * Arguments:	Schema.sObjectType soType - Object type tolocate (SObject.sObjectType)
	 *
	 * Returns:		ITrigger - A trigger handler if one exists or null.
	 */
	private static ITrigger getHandler(Schema.sObjectType soType) {
		
		
		
		String triggerHandlerName = soType.getDescribe().getName().replace('__c', '') + 'Handler';
		
		try{
			return (ITrigger) Type.forName(triggerHandlerName).newInstance();
		}
		catch(System.exception e){
			e.setMessage('Le Trigger Handler de l\'objet ' + soType + ' n\'existe pas, vous devez créer une classe \'' + triggerHandlerName + '.cls\'');
			throw e;
		}
		
		return null;
	}
}