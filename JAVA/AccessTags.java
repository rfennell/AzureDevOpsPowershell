import java.net.URI; 
import java.net.URISyntaxException;

import com.microsoft.tfs.core.TFSTeamProjectCollection; 
import com.microsoft.tfs.core.clients.workitem.WorkItem; 
import com.microsoft.tfs.core.clients.workitem.WorkItemClient; 
import com.microsoft.tfs.core.httpclient.Credentials; 
import com.microsoft.tfs.core.httpclient.DefaultNTCredentials;

public class AccessTags { 
     
      public static String[] GetTagsForWorkItem(URI tfsUri, int workItemId)  
      { 
          // get a reference to the team project collection 
          Credentials credentials = new DefaultNTCredentials(); 
          
          TFSTeamProjectCollection projectCollection = new TFSTeamProjectCollection(tfsUri, credentials); 
          
          // get a reference to the work item tracking service 
          WorkItemClient wic = projectCollection.getWorkItemClient(); 
          
          // get the work item and return the tags 
          WorkItem wi = wic.getWorkItemByID(workItemId); 
          
          // there is no method for the tags, but can pull it out of the fields 
          return wi.getFields().getField("Tags").getValue().toString().split(";"); 
      }

} 